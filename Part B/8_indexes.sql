-- 8.1 (part B - 3.A)

-- b tree
create index father_name_index on "Student"(father_name);
-- hash
create index father_name_index on "Student" using hash(father_name);
-- b tree + clustering
create index father_name_index on "Student"(father_name);
alter table "Student" cluster on father_name_index;
-- testing
explain analyze (select * from "Student" where father_name = 'ΙΚΑΡΟΣ');
-- insert students
select * from ex_3_1_insert_students(100000, '2020-09-10');


-- 8.2 (part B - 3.B)

explain analyze (select distinct s1.amka, s2.amka
from "Student" s1, "Student" s2, "Register" r1, "Register" r2
where s1.father_name = s2.father_name and
      s1.amka <> s2.amka and
      r1.final_grade = r2.final_grade and
      r1.amka = s1.amka and
      r2.amka = s2.amka and
      r1.amka = 3 and -- random amka
      r1.course_code = r2.course_code and
      r1.serial_number = r2.serial_number and
      r1.register_status = 'pass' and
      r2.register_status = 'pass');