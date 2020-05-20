-- 3.1

--========================================================= students
create or replace function ex_3_1_insert_students(count integer, date_entry date) returns void
    volatile
    language plpgsql
as
$$
BEGIN
    INSERT INTO "Student" (
       select (names.id + last_amka.amkas::int) amka,
              names.name as name,
              father_names.name as father_name,
              adapt_surname(surnames.surname, names.sex) as surname,
              concat('s', create_am(extract(year from date_entry)::int, names.id + last_amka.amkas::int), '@isc.tuc.gr')::character(30) as email,
              create_am(extract(year from date_entry)::int, names.id + last_am.ams::int)::character(10) as am,
              date_entry as entry_date
       from random_names(count) as names,
            (select row_number() over ()::int id, sn.surname as surname from (select * from random_surnames(count) s) sn) surnames,
            (select row_number() over ()::int id, fn.name as name, sex from (select n.name as name, sex from "Name" n where sex = 'M' order by random() limit count) fn) father_names,
            (select COUNT(s.am) as ams from "Student" s where s.am like concat(extract(year from date_entry), '%')) last_am,
            (select COUNT(*) as amkas from "Student") last_amka
       where names.id = father_names.id and surnames.id = names.id
    );
END;
$$;
alter function ex_3_1_insert_students(int, date) owner to postgres;

--========================================================= professors
create or replace function ex_3_1_insert_professors(count integer) returns void
    volatile
    language plpgsql
as
$$
BEGIN
    INSERT INTO "Professor" (
         select (names.id + last_amka.amkas::int) amka,
            names.name as name,
            father_names.name as father_name,
            adapt_surname(surnames.surname, names.sex) as surname,
            concat('p', create_am(extract(year from CURRENT_DATE)::int, names.id + last_amka.amkas::int + 30), '@isc.tuc.gr')::character(30) as email,
            floor(random() * (last_lab.labs - 1) + 1)::int as labJoins,
            random_ranks.r as rank
        from random_names(count) as names,
            (select row_number() over ()::int id, sn.surname as surname from (select * from random_surnames(count) s) sn) surnames,
            (select row_number() over ()::int id, fn.name as name, sex from (select n.name as name, sex from "Name" n where sex = 'M' order by random() limit count) fn) father_names,
            (select COUNT(*) + 20000-1 as amkas from "Professor") last_amka,
            (select COUNT(lab_code) as labs from "Lab") last_lab,
            (select row_number() over ()::int id, rand_ranks.r as r
                from (select floor(ids * 4 + 1) as id from generate_series(0, 1, 1.0/count) ids order by random()) rand_id,
                    (select r, row_number() OVER ()::integer as id from unnest(enum_range(NULL::rank_type)) r) rand_ranks
                where rand_id.id = rand_ranks.id) random_ranks
        where names.id = father_names.id and surnames.id = names.id and random_ranks.id = names.id
    );
END;
$$;
alter function ex_3_1_insert_professors(integer) owner to postgres;

--========================================================= lab staff
create or replace function ex_3_1_insert_labstaff(count integer) returns void
    volatile
    language plpgsql
as
$$
BEGIN
    INSERT INTO "LabStaff" (
        select names.id + last_amka.amkas::int amka,
            names.name as name,
            father_names.name as father_name,
            adapt_surname(surnames.surname, names.sex) as surname,
            concat('l', create_am(extract(year from CURRENT_DATE)::int, names.id + last_amka.amkas::int), '@isc.tuc.gr')::character(30) as email,
            floor(random() * (last_lab.labs - 1) + 1) as labworks,
            random_level.l as level
        from random_names(count) as names,
            (select row_number() over ()::int id, sn.surname as surname from (select * from random_surnames(count) s) sn) surnames,
            (select row_number() over ()::int id, fn.name as name, sex from (select n.name as name, sex from "Name" n where sex = 'M' order by random() limit count) fn) father_names,
            (select COUNT(*) + 29999 as amkas from "LabStaff") last_amka,
            (select COUNT(lab_code) as labs from "Lab") last_lab,
            (select row_number() over ()::int id, rand_levels.l as l
                from (select floor(ids * 4 + 1) as id from generate_series(0, 1, 1.0/count) ids order by random()) rand_id,
                    (select l, row_number() OVER ()::integer as id from unnest(enum_range(NULL::level_type)) l) rand_levels
                where rand_id.id = rand_levels.id) random_level
        where names.id = father_names.id and surnames.id = names.id and random_level.id = names.id
    );
END;
$$;
alter function ex_3_1_insert_labstaff(integer) owner to postgres;

-- 3.2

create or replace function ex_3_2_update_score(semester int)
    returns table (amka int, serial_number int,  course_code char(7), exam_grade numeric, final_grade numeric, lab_grade numeric, register_status register_status_type)
    language plpgsql
as
$$
BEGIN
    RETURN QUERY
        select r.amka,
            r.serial_number,
            r.course_code,
            ex_3_2_exam_score(r.amka, r.course_code, semester),
            ex_3_2_final_score(r.amka, r.course_code, semester),
            ex_3_2_lab_score(r.amka, r.course_code, semester),
            r.register_status
        from "Register" r
        where r.serial_number = semester and r.register_status = 'approved';
END;
$$;
alter function ex_3_2_update_score(int) owner to postgres;

create or replace function ex_3_2_lab_score(student_amka int, lab_course_code char(7), current_semester int) returns numeric
    language plpgsql
as
$$
declare
    current_lab_row  "Register" % rowtype;
    previous_lab_row "Register" % rowtype;
    course_lab_row "Course" % rowtype;
begin
    -- check to see if there is a lab grade already
    select * into current_lab_row
    from "Register" r
    where student_amka = r.amka and lab_course_code = r.course_code and r.serial_number = current_semester;
    if current_lab_row.lab_grade is not null then return current_lab_row.lab_grade; end if;

    -- check to see if course has lab
    select * into course_lab_row
    from "Course" c
    where c.course_code = lab_course_code;
    if course_lab_row.lab_hours = 0 then return null; end if;

    -- get previous lab row
    select * into previous_lab_row
    from "Register" r
    where student_amka = r.amka and lab_course_code = r.course_code and r.serial_number = current_semester - 2;

    if previous_lab_row.lab_grade >= 5 then return previous_lab_row.lab_grade; -- get previous grade
    else return floor (random() * 10); end if;  -- generate random

end;
$$;
alter function ex_3_2_lab_score(int, char(7), int) owner to postgres;

create or replace function ex_3_2_exam_score(student_amka int, exam_course_code char(7), current_semester int) returns numeric
    language plpgsql
as
$$
declare
    course_info "CourseRun" % rowtype;
    current_lab_row  "Register" % rowtype;
begin
    -- check to see if an exam grade already exists
    select * into current_lab_row
    from "Register" r
    where student_amka = r.amka and exam_course_code = r.course_code and r.serial_number = current_semester;
    if current_lab_row.exam_grade is not null then return current_lab_row.exam_grade; end if;

    -- get course info
    select * into course_info
    from "CourseRun" cr
    where cr.course_code = exam_course_code and cr.serial_number = current_semester;
    if ex_3_2_lab_score(student_amka, exam_course_code, current_semester) < course_info.lab_min then return 0;
    else return floor (random() * 10); end if;  -- generate random if it doesn't
end;
$$;
alter function ex_3_2_exam_score(int, char(7), int) owner to postgres;

create or replace function ex_3_2_final_score(student_amka int, final_course_code char(7), current_semester int) returns numeric
    language plpgsql
as
$$
declare
    course_info "CourseRun" % rowtype;
    current_lab_row  "Register" % rowtype;
    exam_grade int;
    lab_grade int;
begin
    -- check to see if a final grade already exists
    select * into current_lab_row
    from "Register" r
    where student_amka = r.amka and final_course_code = r.course_code and r.serial_number = current_semester;
    if current_lab_row.final_grade is not null then return current_lab_row.final_grade; end if;

    -- get course info
    select * into course_info
    from "CourseRun" cr
    where cr.course_code = final_course_code and cr.serial_number = current_semester;

    exam_grade = ex_3_2_exam_score(student_amka, final_course_code, current_semester);
    lab_grade = ex_3_2_lab_score(student_amka, final_course_code, current_semester);

    -- Constraints
    if lab_grade is null then return exam_grade;
    elseif lab_grade < course_info.lab_min then return 0; -- if didn't pass lab
    elseif exam_grade < course_info.exam_min then return exam_grade; -- if didn't pass exam
    else return exam_grade * course_info.exam_percentage + lab_grade * (1 - course_info.exam_percentage);
    end if;
end;
$$;
alter function ex_3_2_final_score(int, char(7), int) owner to postgres;

-- 3.3

create or replace function ex_3_3_insert_activities(course char(7), semester int) returns void
    language plpgsql
as
$$
declare
    selected_course record;
    temp_type record;
    temp_room record; temp_weekday record;
    temp_activity "LearningActivity" % rowtype;
    available_start_time int;  expected_end_time int;
begin
    -- extract course information
    select * into selected_course from "Course" c where course = c.course_code;

    drop table if exists hours_type;
    create temporary table hours_type (r_type room_type, act_type activity_type, hours int);

    insert into hours_type values ('lecture_room', 'lecture', selected_course.lecture_hours),
                                  ('lecture_room', 'tutorial', selected_course.tutorial_hours),
                                  ('lab_room', 'lab', selected_course.lab_hours);
    for temp_type in (select * from hours_type)
    loop
         raise notice '%', temp_type;
         <<type_label>> begin -- insert priority: same room -> same weekday -> consecutive hours
            if temp_type.hours > 0 then
                -- Check if hours already exist
                select * into temp_activity from "LearningActivity" la where la.activity_type = temp_type.act_type and la.course_code = course and la.serial_number = semester limit 1;
                if temp_activity is not null then
                    raise notice '% hours already added!', temp_type.act_type;
                    exit type_label;
                end if;

                -- If they don't
                for temp_room in (select r.room_id from "Room" r where r.room_type = temp_type.r_type) -- for each room
                loop
                    for temp_weekday in 1..5 -- for each day (excluding saturday and sunday)
                    loop
                        available_start_time = 8;
                        expected_end_time = available_start_time + temp_type.hours;
                        -- Check if there is any activity on that day
                        select * into temp_activity from "LearningActivity" la where la.weekday = temp_weekday and la.serial_number = semester and la.room_id = temp_room.room_id order by la.start_time limit 1;
                        if temp_activity is null then
                            raise notice 'first activity of the day! Inserting %, %, %, %, %, %, %', temp_type.act_type, available_start_time, expected_end_time, temp_weekday, course, semester, temp_room.room_id;
                            insert into "LearningActivity" values (temp_type.act_type, available_start_time, expected_end_time, temp_weekday, course, semester, temp_room.room_id);
                            exit type_label;
                        -- if there is at least an activity on that day
                        else
                            raise notice 'there is at least one activity on this day! Inserting %, %, %, %, %, %, %', temp_type.act_type, available_start_time, expected_end_time, temp_weekday, course, semester, temp_room.room_id;
                            for temp_activity in (select la.start_time, la.end_time from "LearningActivity" la where la.activity_type = temp_type.act_type and la.weekday = temp_weekday and la.course_code = course and la.serial_number = semester and la.room_id = temp_room.room_id order by la.start_time)
                            loop
                                raise notice '%', temp_activity.start_time;
                                if expected_end_time <= temp_activity.start_time then
                                    insert into "LearningActivity" values (temp_type.act_type, available_start_time, expected_end_time, temp_weekday, course, semester, temp_room.room_id);
                                    exit type_label;
                                else
                                    available_start_time = temp_activity.end_time;
                                    expected_end_time = available_start_time + temp_type.hours;
                                end if;
                            end loop;
                        end if;
                    end loop;
                end loop;
            end if;
        end;
    end loop;
end;
$$;
alter function ex_3_3_insert_activities(char(7), int) owner to postgres;



select * from ex_3_1_insert_students(100000, '2020-09-10')