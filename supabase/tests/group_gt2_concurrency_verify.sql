SELECT public.gt2_assert(
    (SELECT COUNT(*) = 50
     FROM public.learning_group_members
     WHERE group_id = '88888888-8888-4888-8888-888888888888'
       AND role = 'student' AND status = 'active'),
    'concurrent approvals cannot exceed the 50-student cap'
);

SELECT public.gt2_assert(
    (SELECT COUNT(*) = 1
     FROM public.learning_group_members
     WHERE group_id = '88888888-8888-4888-8888-888888888888'
       AND role = 'student' AND status = 'pending'),
    'one concurrent applicant remains pending when the group reaches capacity'
);

SELECT public.gt2_assert(
    (SELECT COUNT(*) = 1
     FROM private.learning_group_moderation_events
     WHERE request_id IN (
        '91000000-0000-4000-8000-000000000002',
        '91000000-0000-4000-8000-000000000003'
     )),
    'only the successful concurrent approval creates an audit event'
);
