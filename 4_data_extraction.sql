--4.1

create or replace function ex_4_1()
    returns TABLE(name character, surname character, amka int)
    immutable
    language plpgsql
as
$$
BEGIN
  RETURN QUERY
    select prof.name, prof.surname, prof.amka
    from "Participates" part, "Professor" prof, "Room" r
    where prof.amka = part.amka and r.room_id = part.room_id and r.capacity > 30
    union
    select ls.name, ls.surname, ls.amka
    from "Participates" part, "LabStaff" ls, "Room" r
    where ls.amka = part.amka and r.room_id = part.room_id and r.capacity > 30;
END;
$$;
alter function ex_4_1() owner to postgres;

--4.2

create or replace function ex_4_2_find_prof_office_hours()
    returns TABLE(name character, surname character, course_code char(7), weekday int, start_time int, end_time int)
    immutable
    language plpgsql
as
$$
BEGIN
  RETURN QUERY
    select p.name, p.surname, cr.course_code, la.weekday, la.start_time, la.end_time
    from "CourseRun" cr, "Semester" s, "LearningActivity" la, "Professor" p
    where semester_status = 'present' and cr.serial_number = s.semester_id and cr.course_code = la.course_code and p.amka = cr.amka_prof1 and la.activity_type = 'office_hours'
    union
    select p.name, p.surname, cr.course_code, la.weekday, la.start_time, la.end_time
    from "CourseRun" cr, "Semester" s, "LearningActivity" la, "Professor" p
    where semester_status = 'present' and cr.serial_number = s.semester_id and cr.course_code = la.course_code and p.amka = cr.amka_prof2 and la.activity_type = 'office_hours';
END;
$$;
alter function ex_4_2_find_prof_office_hours() owner to postgres;

--4.3

create or replace function ex_4_3_get_max_grades(semester int, grade_type char)
    returns TABLE(course_code char(7), grade numeric)
    immutable
    language plpgsql
as
$$
BEGIN
  RETURN QUERY
      select r.course_code,
             case when grade_type = 'exam_grade' then MAX(exam_grade)
                  when grade_type = 'final_grade' then MAX(final_grade)
                  when grade_type = 'lab_grade' then MAX(lab_grade)
                  else 0
             end grade
        from "Register" r
        where serial_number = semester
        group by r.course_code
        order by grade desc;
END;
$$;
alter function ex_4_3_get_max_grades(int, char) owner to postgres;

--4.4

create or replace function ex_4_4_find_students_computer_room()
    returns TABLE(am char(10), year int)
    immutable
    language plpgsql
as
$$
BEGIN
  RETURN QUERY
    select st.am::char(10), extract(year from st.entry_date)::int year_entry
    from "Student" st, "Semester" sem, "Register" reg, "LearningActivity" la, "Room" r
    where st.amka = reg.amka and
          sem.semester_status = 'present' and
          reg.serial_number = sem.semester_id and
          la.course_code = reg.course_code and
          la.room_id = r.room_id and
          la.serial_number = sem.semester_id and
          r.room_type = 'computer_room';
END;
$$;
alter function ex_4_4_find_students_computer_room() owner to postgres;

--4.5

create or replace function ex_4_5_check_afternoon_activities()
    returns TABLE(course_code char(7), bool char(3))
    immutable
    language plpgsql
as
$$
BEGIN
  RETURN QUERY
    select c.course_code,
       case when (la.start_time >= 16 and la.end_time <= 20) then 'ΝΑΙ'::char(3)
            else 'OXI'::char(3)
       end afternoon_activity
    from "Course" c, "LearningActivity" la
    where c.course_code = la.course_code and c.obligatory;
END;
$$;
alter function ex_4_5_check_afternoon_activities() owner to postgres;

--4.6

create or replace function ex_4_6_courses_not_using_labs()
    returns TABLE(course_code char(7), course_title char(100))
    immutable
    language plpgsql
as
$$
BEGIN
    RETURN QUERY
        select c.course_code, c.course_title
        from "Course" c, "Semester" sem, "LearningActivity" la, "Room" r
        where c.course_code = la.course_code and
              c.obligatory and
              c.lab_hours <> 0 and
              la.room_id = r.room_id and
              la.serial_number = sem.semester_id and
              r.room_type <> 'lab_room' and
              sem.semester_status = 'present' and
              sem.academic_season = c.typical_season;
END;
$$;
alter function ex_4_6_courses_not_using_labs() owner to postgres;

--4.7

create or replace function ex_4_7_find_labstaff_workload()
    returns TABLE(amka int, surname char(30), name char(30), hours_of_work int)
    immutable
    language plpgsql
as
$$
BEGIN
    RETURN QUERY
        ((select l.amka, l.surname, l.name, 0 sum
        from "LabStaff" l)
        except
        (select l.amka, l.surname, l.name, 0 sum
        from "LabStaff" l, "Participates" p, "Semester" s
        where l.amka = p.amka and
              s.semester_status = 'present' and
              s.semester_id = p.serial_number))
        union
        (select l.amka, l.surname, l.name, SUM(p.end_time - p.start_time)::int
        from "LabStaff" l, "Participates" p, "Semester" s
        where l.amka = p.amka and
              s.semester_status = 'present' and
              s.semester_id = p.serial_number
        group by l.amka, p.amka, l.surname, l.name);
END;
$$;
alter function ex_4_7_find_labstaff_workload() owner to postgres;

--4.8 (TODO)

create or replace function ex_4_8_find_rooms_with_most_courses()
    returns TABLE(room_id int, count int)
    immutable
    language plpgsql
as
$$
BEGIN
    RETURN QUERY
        select unique_courses.room_id id, COUNT(unique_courses.course_code)::int
        from (select distinct la.course_code, r.room_id, r.room_type
                from "LearningActivity" la, "Room" r
                where la.room_id = r.room_id) unique_courses
        group by unique_courses.room_id
        limit 1;
END;
$$;
alter function ex_4_8_find_rooms_with_most_courses() owner to postgres;

