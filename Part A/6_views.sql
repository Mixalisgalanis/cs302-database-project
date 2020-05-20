-- 6.1

create or replace view ex_6_1 as
select course_code,serial_number,count(*)
from "Register"
where register_status='pass' and lab_grade > 8
group by course_code,serial_number
order by course_code;

-- 6.2

create or replace view ex_6_2 as
select par.room_id, par.weekday, par.start_time, par.end_time, prof.name, prof.surname, par.course_code
from "Participates" par, "Professor" prof, "Semester" sem
where prof.amka = par.amka and sem.semester_status = 'present' and sem.semester_id = par.serial_number
order by par.weekday, par.start_time;
