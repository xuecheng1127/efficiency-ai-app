insert into task_templates (type,title,repeat_mode,start_date,alarm_enabled,created_at) values ('study','T17TEST','daily',strftime('%s','now')*1000,1,strftime('%s','now')*1000);
insert into scheduled_alarms (task_id,hour,minute,repeat_rule,scheduled_date,advance_minute,ringtone,volume,snooze_enabled,snooze_minutes) values (1,1,9,'daily',strftime('%s','now')*1000,0,'chenxi',80,1,5);
