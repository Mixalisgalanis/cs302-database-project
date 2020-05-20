-- 8.1

create index father_name_index on "Student"(father_name);
create index father_name_index on "Student" using hash(father_name);
alter table "Student" cluster on father_name_index;




explain analyze (select * from "Student" where father_name = 'ΙΚΑΡΟΣ');






create or replace function ex_8_1()
    returns TABLE(query_plan text)
    volatile
    language plpgsql
as
$$
DECLARE
    rand_father_name char(30);
BEGIN
    -- generating father name
    select father_name into rand_father_name from "Student" order by random() limit 1;

    drop table if exists analyze_table;
    create temporary table analyze_table (query_plan text);
     --explain analyze (select * from "Student" where father_name = rand_father_name);
    -- without index







    return query
        explain analyze (select * from "Student" where father_name = 'ΙΚΑΡΟΣ');
END;
$$;
alter function ex_8_1() owner to postgres;


select * from ex_8_1();