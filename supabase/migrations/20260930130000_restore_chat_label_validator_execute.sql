-- The Album-label CHECK constraint invokes this pure validator for every chat
-- message, including text messages whose label payload is an empty array.
-- The labels migration revoked EXECUTE from authenticated, so PostgreSQL
-- rejected otherwise-valid inserts with 42501 before the constraint ran.

grant execute on function private.valid_chat_album_image_labels(jsonb)
  to authenticated, service_role;
