-- ==============================================================================
-- EnatAI Seed Script: Dummy Test User & Comprehensive Demo Data
-- ==============================================================================
-- Login Credentials:
--   Email:    testuser@enatai.com
--   Password: password123
--   User ID:  a0000000-0000-0000-0000-000000000001
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

DO $$
DECLARE
    dummy_user_id uuid := 'a0000000-0000-0000-0000-000000000001';
    dummy_email text := 'testuser@enatai.com';
    dummy_password text := 'password123';
BEGIN
    -- 1. Create user in Supabase auth.users (if not existing)
    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = dummy_user_id) THEN
        INSERT INTO auth.users (
            instance_id,
            id,
            aud,
            role,
            email,
            encrypted_password,
            email_confirmed_at,
            raw_app_meta_data,
            raw_user_meta_data,
            created_at,
            updated_at,
            confirmation_token,
            email_change,
            email_change_token_new,
            recovery_token
        ) VALUES (
            '00000000-0000-0000-0000-000000000000',
            dummy_user_id,
            'authenticated',
            'authenticated',
            dummy_email,
            crypt(dummy_password, gen_salt('bf')),
            now(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            '{"name":"Selamawit Tesfaye","gestational_weeks":28}'::jsonb,
            now(),
            now(),
            '',
            '',
            '',
            ''
        );
    ELSE
        -- Update password in case it changed
        UPDATE auth.users 
        SET encrypted_password = crypt(dummy_password, gen_salt('bf')),
            email_confirmed_at = now()
        WHERE id = dummy_user_id;
    END IF;

    -- 2. Create public user profile
    INSERT INTO public.users (id, email, created_at)
    VALUES (dummy_user_id, dummy_email, now() - interval '30 days')
    ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email;

    -- 3. Clear existing test records for clean idempotency
    DELETE FROM public.reminders WHERE user_id = dummy_user_id;
    DELETE FROM public.check_in_sessions WHERE user_id = dummy_user_id;
    DELETE FROM public.summaries WHERE user_id = dummy_user_id;
    DELETE FROM public.check_ins WHERE user_id = dummy_user_id;
    DELETE FROM public.appointments WHERE user_id = dummy_user_id;
    DELETE FROM public.supplements WHERE user_id = dummy_user_id;

    -- 4. Insert Active Supplements
    INSERT INTO public.supplements (id, user_id, name, active, reminder_enabled, reminder_time, created_at)
    VALUES 
        ('b0000000-0000-0000-0000-000000000001', dummy_user_id, 'iron', true, true, '09:00:00', now() - interval '30 days'),
        ('b0000000-0000-0000-0000-000000000002', dummy_user_id, 'folic_acid', true, true, '09:00:00', now() - interval '30 days'),
        ('b0000000-0000-0000-0000-000000000003', dummy_user_id, 'calcium', true, false, '14:00:00', now() - interval '20 days');

    -- 5. Insert Upcoming ANC Appointment
    INSERT INTO public.appointments (id, user_id, appointment_date, last_summary_generated_at, reminder_lead_days)
    VALUES (
        'c0000000-0000-0000-0000-000000000001',
        dummy_user_id,
        (current_date + interval '3 days')::date,
        now() - interval '14 days',
        2
    );

    -- 6. Insert Multiple Check-ins (5 Realistic Intake Check-ins)
    
    -- Check-in 1: 10 days ago (Normal Check-in - No danger signs / feeling fine)
    INSERT INTO public.check_ins (id, user_id, timestamp, symptoms, food_log, supplement_check, closing_mentions, danger_sign_triggered)
    VALUES (
        'd0000000-0000-0000-0000-000000000001',
        dummy_user_id,
        now() - interval '10 days',
        '[{"raw_text": "ደህና ነኝ ምንም ያልተለመደ ስሜት የለም", "category": "no_danger_sign_detected", "duration": {"unit": "unspecified", "value": null}, "severity": "unspecified", "confirmed": true, "danger_sign": false}]'::jsonb,
        '{"raw_text": "እንጀራ በሽሮ እና ሰላጣ", "confirmed": true}'::jsonb,
        '{"raw_text": "የብረት ተጨማሪ ምግብ ወስጃለሁ", "confirmed": true, "taken_today": true, "supplement_name": "iron"}'::jsonb,
        '[]'::jsonb,
        false
    );

    -- Check-in 2: 7 days ago (Mild Fatigue & Normal Pregnancy Back Pain)
    INSERT INTO public.check_ins (id, user_id, timestamp, symptoms, food_log, supplement_check, closing_mentions, danger_sign_triggered)
    VALUES (
        'd0000000-0000-0000-0000-000000000002',
        dummy_user_id,
        now() - interval '7 days',
        '[{"raw_text": "ቀላል የድካም ስሜት እና የጀርባ ህመም", "category": "no_danger_sign_detected", "duration": {"unit": "day", "value": 1}, "severity": "mild", "confirmed": true, "danger_sign": false}]'::jsonb,
        '{"raw_text": "ዳቦ ከወተት እና ሙዝ ጋር", "confirmed": true}'::jsonb,
        '{"raw_text": "የብረት ተጨማሪ ምግብ ወስጃለሁ", "confirmed": true, "taken_today": true, "supplement_name": "iron"}'::jsonb,
        '[]'::jsonb,
        false
    );

    -- Check-in 3: 4 days ago (Persistent Nausea/Vomiting with Nutrition Question)
    INSERT INTO public.check_ins (id, user_id, timestamp, symptoms, food_log, supplement_check, closing_mentions, danger_sign_triggered)
    VALUES (
        'd0000000-0000-0000-0000-000000000003',
        dummy_user_id,
        now() - interval '4 days',
        '[{"raw_text": "ማቅለሽለሽ እና ማስታወክ ለሁለት ቀናት", "category": "persistent_nausea_vomiting", "duration": {"unit": "day", "value": 2}, "severity": "moderate", "confirmed": true, "danger_sign": true}]'::jsonb,
        '{"raw_text": "ሩዝ በሾርባ እና ሻይ", "confirmed": true}'::jsonb,
        '{"raw_text": "ዛሬ አልወሰድኩም ማቅለሽለሽ ስላለኝ", "confirmed": true, "taken_today": false, "supplement_name": "iron"}'::jsonb,
        '[{"topic": "dietary_intake", "raw_text": "ስለ አመጋገብ እና ፈሳሽ መውሰድ ማወቅ እፈልጋለሁ", "confirmed": true}]'::jsonb,
        true
    );

    -- Check-in 4: 2 days ago (High Fever & Headache - Danger Sign Flagged)
    INSERT INTO public.check_ins (id, user_id, timestamp, symptoms, food_log, supplement_check, closing_mentions, danger_sign_triggered)
    VALUES (
        'd0000000-0000-0000-0000-000000000004',
        dummy_user_id,
        now() - interval '2 days',
        '[
            {"raw_text": "ከፍተኛ ትኩሳት", "category": "high_fever", "duration": {"unit": "day", "value": 1}, "severity": "severe", "confirmed": true, "danger_sign": true},
            {"raw_text": "ራስ ምታት", "category": "severe_headache", "duration": {"unit": "day", "value": 1}, "severity": "severe", "confirmed": true, "danger_sign": true}
        ]'::jsonb,
        '{"raw_text": "አጃ አጥሚት", "confirmed": true}'::jsonb,
        '{"raw_text": "የብረት ተጨማሪ ምግብ ወስጃለሁ", "confirmed": true, "taken_today": true, "supplement_name": "iron"}'::jsonb,
        '[{"topic": "other", "raw_text": "ክሊኒክ ሄጄ መታየት አለብኝ?", "confirmed": true}]'::jsonb,
        true
    );

    -- Check-in 5: Today (Improving / Fever Resolved & Breastfeeding Question)
    INSERT INTO public.check_ins (id, user_id, timestamp, symptoms, food_log, supplement_check, closing_mentions, danger_sign_triggered)
    VALUES (
        'd0000000-0000-0000-0000-000000000005',
        dummy_user_id,
        now(),
        '[{"raw_text": "ትኩሳቱ ቀንሷል ዛሬ ደህና ነኝ ምንም አይሰማኝም", "category": "no_danger_sign_detected", "duration": {"unit": "unspecified", "value": null}, "severity": "unspecified", "confirmed": true, "danger_sign": false}]'::jsonb,
        '{"raw_text": "እንጀራ በሚስር ወጥ እና ጎመን", "confirmed": true}'::jsonb,
        '{"raw_text": "የብረት ተጨማሪ ምግብ ወስጃለሁ", "confirmed": true, "taken_today": true, "supplement_name": "iron"}'::jsonb,
        '[{"topic": "breastfeeding_intent", "raw_text": "በወሊድ ወቅት ስለ ጡት ማጥባት ምክር እፈልጋለሁ", "confirmed": true}]'::jsonb,
        false
    );

    -- 7. Insert Clinician Summary Reports (2 Generated Summaries)
    
    -- Summary 1: Past Month Archive Summary
    INSERT INTO public.summaries (id, user_id, period_start, period_end, generated_at, content_json, share_link_slug, qr_code_url)
    VALUES (
        'e0000000-0000-0000-0000-000000000001',
        dummy_user_id,
        (current_date - interval '30 days')::date,
        (current_date - interval '14 days')::date,
        now() - interval '14 days',
        '{
            "danger_signs": [],
            "general_symptoms": [
                {
                    "date": "2026-07-25",
                    "category": "no_danger_sign_detected",
                    "category_display": "ምንም የአደጋ ምልክት አልተገኘም (መደበኛ)",
                    "category_display_en": "no danger sign detected (normal)",
                    "raw_text": "ምንም ህመም የለም ደህና ነኝ",
                    "duration": {"unit": "unspecified", "value": null},
                    "severity": "unspecified"
                }
            ],
            "food_logs": [
                {"date": "2026-07-25", "raw_text": "እንጀራ በሽሮ"}
            ],
            "supplement_adherence": {
                "taken_days": 12,
                "tracked_days": 14
            },
            "closing_mentions": [],
            "muac_reminder": "MUAC screening due — check at visit",
            "provenance_note": "All data in this summary is self-reported by the patient (no device-measured data)."
        }'::jsonb,
        'demo_report_prev_month',
        'https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=https://enatai.com/summary/public/demo_report_prev_month'
    );

    -- Summary 2: Current Period ANC Visit Summary Report
    INSERT INTO public.summaries (id, user_id, period_start, period_end, generated_at, content_json, share_link_slug, qr_code_url)
    VALUES (
        'e0000000-0000-0000-0000-000000000002',
        dummy_user_id,
        (current_date - interval '14 days')::date,
        current_date,
        now(),
        jsonb_build_object(
            'danger_signs', jsonb_build_array(
                jsonb_build_object(
                    'date', (current_date - interval '4 days')::text,
                    'category', 'persistent_nausea_vomiting',
                    'category_display', 'የማይቋረጥ ማስታወክ',
                    'category_display_en', 'persistent nausea or vomiting',
                    'raw_text', 'ማቅለሽለሽ እና ማስታወክ ለሁለት ቀናት',
                    'duration', jsonb_build_object('unit', 'day', 'value', 2),
                    'severity', 'moderate'
                ),
                jsonb_build_object(
                    'date', (current_date - interval '2 days')::text,
                    'category', 'high_fever',
                    'category_display', 'ከፍተኛ ትኩሳት',
                    'category_display_en', 'high fever',
                    'raw_text', 'ከፍተኛ ትኩሳት እና ራስ ምታት',
                    'duration', jsonb_build_object('unit', 'day', 'value', 1),
                    'severity', 'severe'
                )
            ),
            'general_symptoms', jsonb_build_array(
                jsonb_build_object(
                    'date', (current_date - interval '10 days')::text,
                    'category', 'no_danger_sign_detected',
                    'category_display', 'ምንም የአደጋ ምልክት አልተገኘም (መደበኛ)',
                    'category_display_en', 'no danger sign detected (normal)',
                    'raw_text', 'ደህና ነኝ ምንም ያልተለመደ ስሜት የለም',
                    'duration', jsonb_build_object('unit', 'unspecified', 'value', null),
                    'severity', 'unspecified'
                ),
                jsonb_build_object(
                    'date', (current_date - interval '7 days')::text,
                    'category', 'no_danger_sign_detected',
                    'category_display', 'ምንም የአደጋ ምልክት አልተገኘም (መደበኛ)',
                    'category_display_en', 'no danger sign detected (normal)',
                    'raw_text', 'ቀላል የድካም ስሜት እና የጀርባ ህመም',
                    'duration', jsonb_build_object('unit', 'day', 'value', 1),
                    'severity', 'mild'
                ),
                jsonb_build_object(
                    'date', current_date::text,
                    'category', 'no_danger_sign_detected',
                    'category_display', 'ምንም የአደጋ ምልክት አልተገኘም (መደበኛ)',
                    'category_display_en', 'no danger sign detected (normal)',
                    'raw_text', 'ትኩሳቱ ቀንሷል ዛሬ ደህና ነኝ ምንም አይሰማኝም',
                    'duration', jsonb_build_object('unit', 'unspecified', 'value', null),
                    'severity', 'unspecified'
                )
            ),
            'food_logs', jsonb_build_array(
                jsonb_build_object('date', (current_date - interval '10 days')::text, 'raw_text', 'እንጀራ በሽሮ እና ሰላጣ'),
                jsonb_build_object('date', (current_date - interval '7 days')::text, 'raw_text', 'ዳቦ ከወተት እና ሙዝ ጋር'),
                jsonb_build_object('date', (current_date - interval '4 days')::text, 'raw_text', 'ሩዝ በሾርባ እና ሻይ'),
                jsonb_build_object('date', (current_date - interval '2 days')::text, 'raw_text', 'አጃ አጥሚት'),
                jsonb_build_object('date', current_date::text, 'raw_text', 'እንጀራ በሚስር ወጥ እና ጎመን')
            ),
            'supplement_adherence', jsonb_build_object(
                'taken_days', 4,
                'tracked_days', 5
            ),
            'closing_mentions', jsonb_build_array(
                jsonb_build_object('date', (current_date - interval '4 days')::text, 'topic', 'dietary_intake', 'raw_text', 'ስለ አመጋገብ እና ፈሳሽ መውሰድ ማወቅ እፈልጋለሁ'),
                jsonb_build_object('date', (current_date - interval '2 days')::text, 'topic', 'other', 'raw_text', 'ክሊኒክ ሄጄ መታየት አለብኝ?'),
                jsonb_build_object('date', current_date::text, 'topic', 'breastfeeding_intent', 'raw_text', 'በወሊድ ወቅት ስለ ጡት ማጥባት ምክር እፈልጋለሁ')
            ),
            'muac_reminder', 'MUAC screening due — check at visit',
            'provenance_note', 'All data in this summary is self-reported by the patient (no device-measured data).'
        ),
        'demo_report_current_period',
        'https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=https://enatai.com/summary/public/demo_report_current_period'
    );

    -- 8. Reminders & Notifications
    INSERT INTO public.reminders (id, user_id, type, message, due_at, dismissed, created_at)
    VALUES 
        ('f0000000-0000-0000-0000-000000000001', dummy_user_id, 'supplement', 'Reminder to take your daily Iron supplement.', now() + interval '2 hours', false, now()),
        ('f0000000-0000-0000-0000-000000000002', dummy_user_id, 'appointment', 'Upcoming ANC Clinic Visit in 3 days. Your clinical report is ready.', now() + interval '1 day', false, now()),
        ('f0000000-0000-0000-0000-000000000003', dummy_user_id, 'report_generated', 'Your clinician summary report for your ANC appointment has been generated.', now() - interval '1 hour', false, now() - interval '1 hour');

    RAISE NOTICE 'Demo user and complete test dataset seeded successfully!';
END $$;
