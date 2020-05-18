import java.sql.*;
import java.util.HashMap;
import java.util.Stack;

public class Main {

    static Connection connection;

    public static void main(String[] args){
        //Menu System
        int action = -1;
        while (action != 0) {
            displayMainMenu();
            action = Util.readInt("Action: ");
            switch (action) {
                case 0: break;
                case 1:  // Connect to Database
                    connectToDatabase();
                    break;
                case 2:  // Commit
                    commit();
                    break;
                case 3:  // Rollback
                    rollback();
                    break;
                case 4:  // Display registered students
                    displayRegisteredStudents();
                    break;
                case 5:  // Update student grades
                    updateStudentGrades();
                    break;
                default: System.out.println("Action not found!"); break;
            }
        }
    }

    private static void displayMainMenu(){
        System.out.println("\n==== Main Menu Options ====");
        System.out.println("0. Exit");
        System.out.println("---------------------------");
        System.out.println("1. Connect to Database.");
        System.out.println("2. Commit.");
        System.out.println("3. Rollback.");
        System.out.println("4. Display registered students.");
        System.out.println("5. Update student grades.");
        System.out.println("===========================");
    }

    private static void connectToDatabase() {
        String ip = Util.readString("Enter Database IP Address: ");
        String databaseName = Util.readString("Enter Database Name: ");
        String username = Util.readString("Enter User name: ");
        String password = Util.readString("Enter Password: ");

        final int DEFAULT_PORT = 5432;
        //Load the driver class
        try {
            Class.forName("org.postgresql.Driver");
            System.out.println("Driver class found!");
        } catch (ClassNotFoundException ex) {
            System.out.println("Unable to load the class. Terminating the program");
            System.exit(-1);
        }

        //get the connection
        try {
            connection = DriverManager.getConnection("jdbc:postgresql://" + ip + ":" + DEFAULT_PORT + "/" + databaseName, username, password);
            System.out.println("Successfully connected to database! " + databaseName);
            connection.setAutoCommit(false);
            System.out.println("Auto-Commit mode disabled!");
        } catch (Exception ex) {
            System.out.println("Error: " + ex.getMessage());
        }
    }

    public static void commit(){
        try {
            if (connection == null) connectToDatabase();
            connection.commit();
            System.out.println("Transaction Completed!");
        } catch (SQLException e) {
            e.printStackTrace();
        }
    }

    public static void rollback() {
        try {
            if (connection == null) connectToDatabase();
            connection.rollback();
            System.out.println("Transaction cancelled!");
        } catch (SQLException e) {
            e.printStackTrace();
        }
    }

    public static void rollback(Savepoint sp) {
        try {
            if (connection == null) connectToDatabase();
            connection.rollback(sp);
            System.out.println("Transaction cancelled!");
        } catch (SQLException e) {
            e.printStackTrace();
        }
    }

    public static void displayRegisteredStudents(){
        if (connection == null) connectToDatabase();

        String academicYear = Util.readString("Enter Academic Year: ");
        String academicSeason = Util.readString("Enter Academic Season: ");
        String courseCode = Util.readString("Enter course code: ");

        try{
            Statement statement = connection.createStatement();
            ResultSet rs = statement.executeQuery("select r.amka from \"Semester\" s, \"Register\" r where s.academic_year = " + academicYear + " and s.academic_season = \'" + academicSeason + "\' and r.course_code = \'" + courseCode + "\' and s.semester_id = r.serial_number and r.register_status <> 'rejected' and r.register_status <> 'proposed' order by r.amka");

            while (rs.next()) {
                System.out.println("amka = " + rs.getInt(1));
            }

            rs.close();
        } catch (SQLException e) {
            rollback();
            e.printStackTrace();
        }
    }

    public static void updateStudentGrades(){
        if (connection == null) connectToDatabase();

        String academicYear = Util.readString("Enter Academic Year: ");
        String academicSeason = Util.readString("Enter Academic Season: ");
        String amka = Util.readString("Enter Student amka: ");

        try{
            HashMap<Integer, String> courses = new HashMap<>();

            // Displaying current student grades
            Statement statement = connection.createStatement();
            ResultSet rs = statement.executeQuery("select row_number() over ()::int id, c.course_code, c.course_title, r.lab_grade, r.exam_grade from \"Course\" c, \"Register\" r, \"Semester\" s where s.academic_year = " + academicYear + " and s.academic_season = \'" + academicSeason + "\' and r.amka = " + amka + " and s.semester_id = r.serial_number and c.course_code = r.course_code and r.register_status <> 'rejected' and r.register_status <> 'proposed' order by id\n");

            while (rs.next()) {
                int tempId = rs.getInt(1);
                String tempCourseCode = rs.getString(2);
                courses.put(tempId, tempCourseCode);
                System.out.println("id = " + tempId + ", course_code = " + tempCourseCode + ", course_title = " + rs.getString(3) + ", lab_grade = " + rs.getFloat(4) + ", exam_grade = " + rs.getFloat(5));
            }
            rs.close();

            // Modifying student grades
            Stack<Savepoint> stack = new Stack<>();
            int id = -1;
            while (id != 0) {
                id = Util.readInt("Enter id to modify: ");
                if (id == 0) continue;
                else if (id == -1) {
                    if (stack.empty()) {
                        System.out.println("There is no savepoint to rollback to.");
                        continue;
                    }
                    Savepoint sp = stack.pop();
                    rollback(sp);
                    System.out.println("Rolling back to previous savepoint.");
                    continue;
                }
                else if (courses.get(id) == null){
                    System.out.println("Course not found!");
                    continue;
                }

                String labGrade = Util.readString("Enter new lab grade: ");
                String examGrade = Util.readString("Enter new exam grade: ");

                Savepoint sp = connection.setSavepoint();
                stack.push(sp);

                statement = connection.createStatement();
                statement.executeUpdate("update \"Register\" r set lab_grade = " + labGrade + ", exam_grade = " + examGrade + " from \"Semester\" s where amka = " + amka + " and s.academic_year = " + academicYear + " and s.academic_season = \'" + academicSeason + "\' and r.course_code = \'" + courses.get(id) + "\' and r.serial_number = s.semester_id");
            }
            connection.commit();

            // Displaying new student grades
            statement = connection.createStatement();
            rs = statement.executeQuery("select row_number() over ()::int id, c.course_code, c.course_title, r.lab_grade, r.exam_grade from \"Course\" c, \"Register\" r, \"Semester\" s where s.academic_year = " + academicYear + " and s.academic_season = \'" + academicSeason + "\' and r.amka = " + amka + " and s.semester_id = r.serial_number and c.course_code = r.course_code and r.register_status <> 'rejected' and r.register_status <> 'proposed' order by id\n");

            while (rs.next()) {
                int tempId = rs.getInt(1);
                String tempCourseCode = rs.getString(2);
                courses.put(tempId, tempCourseCode);
                System.out.println("id = " + tempId + ", course_code = " + tempCourseCode + ", course_title = " + rs.getString(3) + ", lab_grade = " + rs.getFloat(4) + ", exam_grade = " + rs.getFloat(5));
            }
            rs.close();
        } catch (SQLException e) {
            rollback();
            e.printStackTrace();
        }
    }
}
