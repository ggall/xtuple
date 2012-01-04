﻿select private.create_model(

-- Model name, schema, table

'todo_alarm', 'public', 'alarm',

-- Columns

E'{"
  "alarm.alarm_id as guid",
  "alarm.alarm_number as number",
  "alarm.alarm_email as email",
  "alarm.alarm_email_recipient as email_recipient",
  "alarm.alarm_event as event",
  "alarm.alarm_event_recipient as event_recipient",
  "alarm.alarm_sysmsg as message",
  "alarm.alarm_sysmsg_recipient as message_recipient",
  "alarm.alarm_time_offset as offset",
  "alarm.alarm_time_qualifier as qualifier",
  "alarm.alarm_time as time",
  "alarm.alarm_trigger as trigger",
  "alarm.alarm_source as source"}',

-- Rules

E'{"

-- insert rule

create or replace rule \\"_CREATE\\" as on insert to xm.todo_alarm 
  do instead

insert into alarm ( 
  alarm_id,
  alarm_number,
  alarm_email,
  alarm_email_recipient,
  alarm_event,
  alarm_event_recipient,
  alarm_sysmsg,
  alarm_sysmsg_recipient,
  alarm_time_offset,
  alarm_time_qualifier,
  alarm_time,
  alarm_trigger,
  alarm_source )
values (
  new.guid,
  new.number,  
  new.email,
  new.email_recipient,
  new.event,
  new.event_recipient,
  new.message,
  new.message_recipient,
  new.offset,
  new.qualifier,
  new.time,
  new.trigger,
  \'TODO\' );
  
","
-- update rule

create or replace rule \\"_UPDATE\\" as on update to xm.todo_alarm
  do instead
  
update alarm set
  alarm_number = new.number,
  alarm_email = new.email,
  alarm_email_recipient = new.email_recipient,
  alarm_event = new.event,
  alarm_event_recipient = new.event_recipient,
  alarm_sysmsg = new.message,
  alarm_sysmsg_recipient = new.message_recipient,
  alarm_time_offset = new.offset,
  alarm_time_qualifier = new.qualifier,
  alarm_time = new.time,
  alarm_trigger = new.trigger
where ( alarm_id = old.guid );

","

-- delete rules

create or replace rule \\"_DELETE\\" as on delete to xm.todo_alarm   
  do instead
  
delete from alarm 
where ( alarm_id = old.guid );

"}', 

-- Conditions, Comment, System
'{"alarm.alarm_source = \'TODO\'"}', 'Todo Alarm Model', true);