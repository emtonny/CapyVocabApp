UPDATE public.users SET phone = NULL WHERE id = '88035d0c-764b-4922-91e5-28c2480b1385';

ALTER TABLE public.users
  ADD CONSTRAINT users_phone_key UNIQUE (phone);;
