package com.mycompany.toysharingmanagement.dao;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;

/**
 * Lớp kết nối CSDL dùng chung cho toàn bộ dự án.
 *
 * QUAN TRỌNG: lớp này ĐÃ ĐƯỢC CHUYỂN từ default package (không có "package ...")
 * sang package com.mycompany.toysharingmanagement.dao.
 * Lý do: Java KHÔNG cho phép 1 class có package import 1 class ở default package.
 * Nếu để nguyên như file gốc, mọi DAO (của cả 3 người) đều không compile được.
 * -> Mọi DAO đều nằm cùng package này nên KHÔNG cần import DBContext nữa,
 *    chỉ cần `extends DBContext` là dùng được field `connection` (protected).
 *    Nếu có class ở package khác cần dùng, import bằng:
 *    `import com.mycompany.toysharingmanagement.dao.DBContext;`
 */
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
