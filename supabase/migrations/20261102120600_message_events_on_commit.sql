-- message.created with the attachments.
--
-- send_message inserts the message, then links its photos or voice note to
-- it. The row trigger on_message_notify ran at the insert, so message.created
-- and the lastMessage of chat.updated went out with "attachments": [] and the
-- other members saw an empty photo or voice bubble until they reloaded the
-- chat. Found by the client's integration test (integration/supabase).
--
-- As a constraint trigger deferred to commit it builds the events from the
-- finished message, and a rolled back send broadcasts nothing.

drop trigger on_message_notify on public.messages;

create constraint trigger on_message_notify
  after insert on public.messages
  deferrable initially deferred
  for each row execute function private.on_message_notify();
