--===================================================================== create data types
--activity type
create type activity_type as enum ('lecture', 'tutorial', 'computer_lab', 'lab',  'office_hours');
alter type level_type owner to postgres;

--role type
create type role_type as enum ('responsible', 'participant');
alter type level_type owner to postgres;

--room type
create type room_type as enum ('lecture_room', 'computer_room', 'lab_room', 'office');
alter type level_type owner to postgres;


--=====================================================================  create tables

--room
create table "Room" (
    room_id int not null,
    capacity int not null,
    room_type room_type not null,
    constraint "Room_pkey" primary key (room_id)
);
alter table "Room" owner to postgres;

--learning activity
create table "LearningActivity" (
    activity_type activity_type not null,
    start_time int not null check (start_time >= 8 and start_time <= 20),
    end_time int not null check (end_time >= 8 and end_time <= 20),
    weekday int not null check (weekday >= 0 and weekday <= 6),
    course_code char(7) not null,
    serial_number int not null,
    room_id int not null,
    constraint "LearningActivity_pkey" primary key (start_time, end_time, weekday, course_code, serial_number),
    constraint "CourseRun_fkey" foreign key (serial_number, course_code)
        references public."CourseRun" (serial_number, course_code),
    constraint "Room_fkey" foreign key (room_id)
        references public."Room" (room_id)
);
alter table "LearningActivity" owner to postgres;

--Participates
create table "Participates" (
    role role_type not null,
    amka int not null,
    room_id int not null,
    start_time int not null check (start_time >= 8 and start_time <= 20),
    end_time int not null check (end_time >= 8 and end_time <= 20),
    weekday int not null check (weekday >= 0 and weekday <= 6),
    course_code char(7) not null,
    serial_number int not null,
    constraint "Participates_pkey" primary key (amka, room_id, start_time, end_time, weekday, course_code, serial_number),
    constraint "LearningActivity_fkey" foreign key (start_time, end_time, weekday, course_code, serial_number)
        references public."LearningActivity" (start_time, end_time, weekday, course_code, serial_number),
    constraint "Room_fkey" foreign key (room_id)
        references public."Room" (room_id),
    constraint "Person_fkey" foreign key (amka)
        references public."Person" (amka)
);
alter table "Participates" owner to postgres;

--Person
create table "Person" (
    amka int not null,
    name char(30) not null,
    father_name char(30) not null,
    surname char(30) not null,
    email char(30) not null,
    constraint "Person_pkey" primary key (amka)
);
alter table "Person" owner to postgres;

--fill people
insert into "Person"(
                    (select amka, name, father_name, surname, email
                    from "Student")
                    union
                    (select amka, name, father_name, surname, email
                    from "Professor")
                    union
                    (select amka, name, father_name, surname, email
                    from "LabStaff")
                    order by amka
);

-- fill Rooms
insert into "Room" VALUES ( 1, 150, 'lecture_room');
insert into "Room" VALUES ( 2, 30, 'computer_room');
insert into "Room" VALUES ( 3, 20, 'lab_room');
insert into "Room" VALUES ( 4, 220, 'lecture_room');
insert into "Room" VALUES ( 5, 10, 'office');

-- fill Learning activity
insert into "LearningActivity" VALUES ('lecture', 9, 11, 1, 'ΑΓΓ 101', 21, 1);
insert into "LearningActivity" VALUES ('lecture', 11, 13, 2, 'ΑΓΓ 102', 24, 4);
insert into "LearningActivity" VALUES ('lecture', 15, 17, 1, 'ΜΑΘ 201', 21, 1);
insert into "LearningActivity" VALUES ('lecture', 12, 14, 3, 'ΜΑΘ 102', 22, 1);
insert into "LearningActivity" VALUES ('lecture', 16, 18, 5, 'ΜΑΘ 101', 21, 1);
insert into "LearningActivity" VALUES ('lecture', 15, 17, 2, 'ΜΑΘ 102', 22, 4);
insert into "LearningActivity" VALUES ('lecture', 11, 14, 4, 'ΠΛΗ 302', 22, 4);
insert into "LearningActivity" VALUES ('lecture', 15, 17, 2, 'ΜΑΘ 101', 21, 1);

-- fill Participates
insert into "Participates" VALUES ('responsible', 20005, 4, 9, 11, 1, 'ΑΓΓ 101', 21);
insert into "Participates" VALUES ('responsible', 20008, 1, 11, 13, 2, 'ΑΓΓ 102', 24);
insert into "Participates" VALUES ('responsible', 20004, 1, 15, 17, 1, 'ΜΑΘ 201', 21);
insert into "Participates" VALUES ('responsible', 20012, 1, 12, 14, 3, 'ΜΑΘ 102', 22);
insert into "Participates" VALUES ('participant', 20029, 4, 16, 18, 5, 'ΜΑΘ 101', 21);
insert into "Participates" VALUES ('participant', 20018, 4, 15, 17, 2, 'ΜΑΘ 102', 22);
insert into "Participates" VALUES ('participant', 20020, 1, 11, 14, 4, 'ΠΛΗ 302', 22);
insert into "Participates" VALUES ('participant', 20002, 1, 15, 17, 2, 'ΜΑΘ 101', 21);

