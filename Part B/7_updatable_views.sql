-- 7.1

create or replace view ex_7_1 as
select *
from "Room"
where room_type = 'lecture_room';

-- 7.2

create or replace view ex_7_2 as
select p.course_code, l.lab_title, string_agg(concat(rtrim(ls.name), ' ', rtrim(ls.surname)), ', ') full_name, string_agg(ls.email, ', ') email, p.weekday, p.start_time, p.end_time, p.room_id
from "Participates" p, "LearningActivity" la, "Lab" l, "LabStaff" ls, "Sector" s, "Semester" sem, "Room" r
where p.amka = ls.amka and
      ls.labworks = l.lab_code and
      l.sector_code = s.sector_code and
      s.sector_title = 'Τομέας Πληροφορικής' and
      p.role = 'responsible' and
      p.start_time = la.start_time and
      p.end_time = la.end_time and
      p.weekday = la.weekday and
      p.course_code = la.course_code and
      p.serial_number = la.serial_number and
      p.room_id = la.room_id and
      sem.semester_id = p.serial_number and
      sem.semester_status = 'present' and
      la.activity_type = 'lab' and
      r.room_id = la.room_id and
      r.room_type = 'lab_room'
group by p.course_code, l.lab_title, p.course_code, p.weekday, p.start_time, p.end_time, p.room_id;

create trigger ex_7_2_trigger instead of update
    on "ex_7_2"
    for each row
    execute procedure ex_7_2_handler();

create or replace function ex_7_2_handler() returns trigger
    volatile
    language plpgsql
as
$$
    DECLARE
        temp_new_personell record;
        expected_lab record;
        expected_personell record;
        temp_participates "Participates" % rowtype;
        counter int = 1;
    BEGIN
        -- CHECK #1 : restricted fields
        if new.course_code <> old.course_code or new.weekday <> old.weekday or new.start_time <> old.start_time or new.end_time <> old.end_time or new.room_id <> old.room_id then
            raise notice 'RESTRICTED FIELDS!';
            return old;
        end if;

        -- check and insert new lab staff
        for temp_new_personell in (select * from ex_7_2_extract_personell_info(new.full_name, new.email))
        loop
            -- CHECK #2 : validness of lab
            select l.lab_code into expected_lab from "Lab" l, "Sector" s where l.sector_code = s.sector_code and l.lab_title = new.lab_title and s.sector_title = 'Τομέας Πληροφορικής';
            if expected_lab is null then
                raise notice 'NEW LAB IS INVALID!';
                return old;
            end if;

            -- CHECK #3 : validness of lab staff (full_names and emails)
            select l.name, l.surname, l.email into expected_personell from "LabStaff" l where l.name = temp_new_personell.name and l.surname = temp_new_personell.surname;
            if expected_personell is null or temp_new_personell.email <> expected_personell.email then
                raise notice 'NEW FULL_NAME OR EMAIL IS INVALID!';
                return old;
            end if;

            -- Update working lab of old lab staff with new lab code
            update "LabStaff" ls set labworks = expected_lab.lab_code where ls.amka = temp_new_personell.amka;
            -- Insert new personell if not present already
            select p.role, p.amka, p.room_id, p.start_time, p.end_time, p.weekday, p.course_code, p.serial_number into temp_participates from "Participates" p, ex_7_2_extract_personell_info(old.full_name, old.email) old_pi, "Semester" sem where p.role = 'responsible' and p.amka = old_pi.amka and temp_new_personell.id = old_pi.id and p.room_id = new.room_id and p.start_time = new.start_time and p.end_time = new.end_time and p.weekday = new.weekday and p.course_code = new.course_code and p.serial_number = sem.semester_id and sem.semester_status = 'present';
            if temp_participates is null then
                insert into "Participates" values ('responsible', temp_new_personell.amka, new.room_id, new.start_time, new.end_time, new.weekday, new.course_code, (select semester_id from "Semester" where semester_status = 'present')) on conflict do nothing;
            end if;
            counter = counter + 1;
        end loop;

        -- remove excess old lab staff (in case the new lab staff has less people than before)
        delete from "Participates" p using "Semester" sem, ex_7_2_extract_personell_info(new.full_name, new.email) old_pi where sem.semester_status = 'present' and sem.semester_id = p.serial_number and p.role = 'responsible' and p.amka = old_pi.amka and old.room_id = p.room_id and old.start_time = p.start_time and old.end_time = p.end_time and old.weekday = p.weekday and old.course_code = p.course_code and old_pi.id >= counter;
        return new;
    END;
$$;

create or replace function ex_7_2_extract_personell_info(full_names text, emails text) returns table (id int, amka int, name char(30), surname char(30), email text)
    volatile
    language plpgsql
as
$$
    DECLARE
        temp_personell record;

        temp_amka int;
        temp_name char(30);
        temp_surname char(30);
        temp_email text;

        counter int = 1;
    BEGIN
        drop table if exists personell_info;
        create temporary table personell_info (id int, amka int, name char(30), surname char(30), email text);
        for temp_personell in (select unnest(string_to_array(full_names, ', ')) full_name, unnest(string_to_array(emails, ', ')) email)
        loop
            temp_name = (select string_to_array(temp_personell.full_name, ' '))[1];
            temp_surname = (select string_to_array(temp_personell.full_name, ' '))[2];
            temp_amka = (select l.amka from "LabStaff" l where l.name = temp_name and l.surname = temp_surname);
            temp_email = temp_personell.email;
            insert into personell_info values (counter, temp_amka, temp_name, temp_surname, temp_email);
            counter = counter + 1;
        end loop;
        return query (select * from personell_info);
    END;
$$;
