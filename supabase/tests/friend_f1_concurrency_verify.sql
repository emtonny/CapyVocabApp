SELECT public.f1_assert(
    (SELECT COUNT(*) = 1
     FROM public.friends
     WHERE user_id IN (
             '66666666-6666-4666-8666-666666666666'::UUID,
             '77777777-7777-4777-8777-777777777777'::UUID
         )
       AND friend_id IN (
             '66666666-6666-4666-8666-666666666666'::UUID,
             '77777777-7777-4777-8777-777777777777'::UUID
         )
       AND status = 'pending'),
    'simultaneous opposite sends create one directional pending request'
);
