--================================================5.1
-- insert

create trigger ex_5_1_trigger_insert_check_participants before insert
    on "Participates"
    for each row
    execute procedure ex_5_1_handler_insert_check_participants();
create or replace function ex_5_1_handler_insert_check_participants() returns trigger
    volatile
    language plpgsql
as
$$
    DECLARE
        rec record;
        student "Student"% rowtype;
        course_rec record;
    BEGIN
        for rec in (select * from "Participates")
        loop
            -- check for conflicting activity hours
            if (rec.amka = new.amka and rec.weekday = new.weekday and ((new.end_time > rec.start_time and new.end_time < rec.end_time) or (new.start_time < rec.end_time and new.start_time > rec.start_time))) then
                return null;
            end if;

            -- check for lab hours
            select * into student from "Student" where amka = new.amka;
            if (student is not null) then
                select course.course_code into course_rec
                from (select course_lab_hours.course_code
                                from
                                    (select p.course_code, SUM(p.end_time - p.start_time) sum, c.lab_hours
                                    from "Participates" p, "LearningActivity" la, "Course" c
                                    where p.course_code = la.course_code and
                                          p.course_code = c.course_code and
                                          p.course_code = new.course_code and
                                          p.room_id = la.room_id and
                                          p.start_time = la.start_time and
                                          p.end_time = la.end_time and
                                          p.weekday = la.weekday and
                                          p.serial_number = la.serial_number and
                                          (la.activity_type = 'lab' or la.activity_type = 'computer_lab')
                                    group by p.course_code, c.lab_hours) course_lab_hours
                                where course_lab_hours.sum + (new.end_time - new.start_time) > course_lab_hours.lab_hours) course;
                if (course_rec is not null) then
                    return null;
                end if;
            end if;
        end loop;
        return new;
    END;
$$;
alter function ex_5_1_handler_insert_check_participants() owner to postgres;

-- update
create trigger ex_5_1_trigger_update_check_participants before update
    on "Participates"
    for each row
    execute procedure ex_5_1_handler_update_check_participants();
create or replace function ex_5_1_handler_update_check_participants() returns trigger
    volatile
    language plpgsql
as
$$
    DECLARE
        rec record;
        student "Student"% rowtype;
        course_rec record;
    BEGIN
        for rec in (select * from "Participates")
        loop
            -- check for conflicting activity hours
            if (rec.amka = new.amka and rec.weekday = new.weekday and ((new.end_time > rec.start_time and new.end_time < rec.end_time) or (new.start_time < rec.end_time and new.start_time > rec.start_time))) then
                return old;
            end if;

            -- check for lab hours
            select * into student from "Student" where amka = new.amka;
            if (student is not null) then
                select course.course_code into course_rec
                from (select course_lab_hours.course_code
                                from
                                    (select p.course_code, SUM(p.end_time - p.start_time) sum, c.lab_hours
                                    from "Participates" p, "LearningActivity" la, "Course" c
                                    where p.course_code = la.course_code and
                                          p.course_code = c.course_code and
                                          p.course_code = new.course_code and
                                          p.room_id = la.room_id and
                                          p.start_time = la.start_time and
                                          p.end_time = la.end_time and
                                          p.weekday = la.weekday and
                                          p.serial_number = la.serial_number and
                                          (la.activity_type = 'lab' or la.activity_type = 'computer_lab')
                                    group by p.course_code, c.lab_hours) course_lab_hours
                                where course_lab_hours.sum + (new.end_time - new.start_time) > course_lab_hours.lab_hours) course;
                if (course_rec is not null) then
                    return old;
                end if;
            end if;
        end loop;
        return new;
    END;
$$;
alter function ex_5_1_handler_update_check_participants() owner to postgres;


--================================================5.2

-- insert
create trigger ex_5_2_trigger_insert_check_activities before insert
    on "LearningActivity"
    for each row
    execute procedure ex_5_2_handler_insert_check_activities();
create or replace function ex_5_2_handler_insert_check_activities() returns trigger
    volatile
    language plpgsql
as
$$
    DECLARE
        rec record;
    BEGIN
        for rec in (select * from "LearningActivity")
        loop
            -- check if day is working day (start_time and end_time already have constraints by the table's properties)
            if (new.weekday < 1 or new.weekday > 5) then
                return null;
            end if;

            -- checks for conflicts
            if (new.weekday = rec.weekday and new.serial_number = rec.serial_number and rec.room_id = new.room_id and
                ((new.end_time > rec.start_time and new.end_time < rec.end_time) or (new.start_time < rec.end_time and new.start_time > rec.start_time))) then
                return null;
            end if;
        end loop;
        return new;
    END;
$$;
alter function ex_5_2_handler_insert_check_activities() owner to postgres;

-- update
create trigger ex_5_2_trigger_update_check_activities before update
    on "LearningActivity"
    for each row
    execute procedure ex_5_2_handler_update_check_activities();
create or replace function ex_5_2_handler_update_check_activities() returns trigger
    volatile
    language plpgsql
as
$$
    DECLARE
        rec record;
    BEGIN
        for rec in (select * from "LearningActivity")
        loop
            -- check if day is working day (start_time and end_time already have constraints by the table's properties)
            if (new.weekday < 1 or new.weekday > 5) then
                return old;
            end if;

            -- checks for conflicts
            if (new.weekday = rec.weekday and new.serial_number = rec.serial_number and rec.room_id = new.room_id and
                ((new.end_time > rec.start_time and new.end_time < rec.end_time) or (new.start_time < rec.end_time and new.start_time > rec.start_time))) then
                return old;
            end if;
        end loop;
        return new;
    END;
$$;
alter function ex_5_2_handler_update_check_activities() owner to postgres;

--================================================5.3

-- insert
create trigger ex_5_3_trigger_insert_new_courses after insert
    on "Semester"
    for each row
    execute procedure ex_5_3_handler_insert_new_courses();
create or replace function ex_5_3_handler_insert_new_courses() returns trigger
    volatile
    language plpgsql
as
$$
    DECLARE
        current_course record;
        last_course record;
    BEGIN
        if new.semester_status <> 'future' then return new;
        end if;
        for current_course in (select c.course_code from "Course" c where c.typical_season = new.academic_season)
        loop
            select * into last_course from "CourseRun" cr where cr.course_code = current_course.course_code order by serial_number desc limit 1;
            insert into "CourseRun" values (current_course.course_code, new.semester_id, last_course.exam_min, last_course.lab_min, last_course.exam_percentage, last_course.labuses, new.semester_id, last_course.amka_prof1, last_course.amka_prof2);
        end loop;
        return new;
    END;
$$;
alter function ex_5_3_handler_insert_new_courses() owner to postgres;