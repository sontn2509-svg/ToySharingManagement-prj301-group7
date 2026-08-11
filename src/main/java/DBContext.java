/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Classes/Class.java to edit this template
 */

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;

public class DBContext {

    protected Connection connection;

    public DBContext() {
        try {
            
            String user = "sa";
            String pass = "123";
            String serverName = "localhost";
            String portNumber = "1433";
            String dbName = "ToySharingManagement";
            
            String url = "jdbc:sqlserver://" + serverName + ":" + portNumber 
                       + ";databaseName=" + dbName 
                       + ";encrypt=true;trustServerCertificate=true;";

            Class.forName("com.microsoft.sqlserver.jdbc.SQLServerDriver");
            connection = DriverManager.getConnection(url, user, pass);
        } catch (ClassNotFoundException | SQLException ex) {
            System.err.println("Lỗi kết nối CSDL: " + ex.getMessage());
        }
    }

    public Connection getConnection() {
        return connection;
    }

    // Hàm main dùng để test nhanh kết nối
    public static void main(String[] args) {
        DBContext db = new DBContext();
        if (db.getConnection() != null) {
            System.out.println("===> oke roi !");
        } else {
            System.out.println("===> xem lại password hay xem lại cấu hình sql nhé.");
        }
    }
}
