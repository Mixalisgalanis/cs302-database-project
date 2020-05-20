import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;

public class Util {

    private static final BufferedReader in = new BufferedReader(new InputStreamReader(System.in));

    public static int readInt(String message) {
        System.out.print(message);
        try {
            String str = in.readLine();
            return Integer.parseInt(str);
        } catch (IOException | NumberFormatException ex) {
            return -1;
        }
    }

    public static String readString(String message) {
        System.out.println(message);
        try {
            return (in.readLine());
        } catch (IOException ex) {
            return null;
        }
    }
}
