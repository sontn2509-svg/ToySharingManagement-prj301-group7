-- =========================================================
-- DATABASE: ToySharingManagement (SQL Server / T-SQL)
-- Đề tài: Quản lý chia sẻ đồ chơi trẻ em (User & Admin)
-- Nhóm 7 - Chạy trực tiếp trong SQL Server Management Studio (SSMS)
-- =========================================================

IF DB_ID('ToySharingManagement') IS NOT NULL
    DROP DATABASE ToySharingManagement;
GO

CREATE DATABASE ToySharingManagement;
GO

USE ToySharingManagement;
GO

-- ---------------------------------------------------------
-- 1. BẢNG USERS
-- ---------------------------------------------------------
CREATE TABLE users (
    user_id       INT IDENTITY(1,1) PRIMARY KEY,
    username      NVARCHAR(50)  NOT NULL UNIQUE,
    password      NVARCHAR(255) NOT NULL,       -- lưu mật khẩu đã băm (BCrypt...)
    full_name     NVARCHAR(100) NOT NULL,
    email         NVARCHAR(100) NOT NULL UNIQUE,
    phone         NVARCHAR(15)  NULL,
    address       NVARCHAR(255) NULL,
    avatar        NVARCHAR(255) NULL,
    role          VARCHAR(10)  NOT NULL DEFAULT 'USER'   CHECK (role IN ('USER','ADMIN')),
    status        VARCHAR(10)  NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','LOCKED')),
    created_at    DATETIME NOT NULL DEFAULT GETDATE(),
    updated_at    DATETIME NOT NULL DEFAULT GETDATE()
);
GO
-- Ghi chú: không có luồng "admin tạo user" — mọi user đều tự đăng ký.
-- Admin chỉ được UPDATE cột status/role, không sửa full_name/email/phone/address (ràng buộc ở tầng ứng dụng).

-- ---------------------------------------------------------
-- 2. BẢNG CATEGORIES
-- ---------------------------------------------------------
CREATE TABLE categories (
    category_id   INT IDENTITY(1,1) PRIMARY KEY,
    category_name NVARCHAR(100) NOT NULL UNIQUE,
    description   NVARCHAR(255) NULL
);
GO

-- ---------------------------------------------------------
-- 3. BẢNG TOYS
-- ---------------------------------------------------------
CREATE TABLE toys (
    toy_id           INT IDENTITY(1,1) PRIMARY KEY,
    owner_id         INT NOT NULL,
    category_id      INT NOT NULL,
    toy_name         NVARCHAR(150) NOT NULL,
    description      NVARCHAR(MAX) NULL,
    age_range        NVARCHAR(50)  NULL,
    condition_status VARCHAR(10) NOT NULL DEFAULT 'GOOD'      CHECK (condition_status IN ('NEW','GOOD','FAIR')),
    image            NVARCHAR(255) NULL,
    status           VARCHAR(10) NOT NULL DEFAULT 'AVAILABLE' CHECK (status IN ('AVAILABLE','BORROWED','HIDDEN','DELETED')),
    created_at       DATETIME NOT NULL DEFAULT GETDATE(),
    updated_at       DATETIME NOT NULL DEFAULT GETDATE(),

    CONSTRAINT fk_toys_owner    FOREIGN KEY (owner_id)    REFERENCES users(user_id),
    CONSTRAINT fk_toys_category FOREIGN KEY (category_id) REFERENCES categories(category_id)
);
GO
-- Lưu ý: không dùng ON DELETE CASCADE — vì borrow_requests tham chiếu tới cả toys và users,
-- SQL Server sẽ báo lỗi "multiple cascade paths" nếu bật cascade ở nhiều tầng.
-- Điều này cũng khớp đúng nghiệp vụ: không hard-delete user/toy, chỉ soft-delete qua cột status.

CREATE INDEX idx_toys_status   ON toys(status);
CREATE INDEX idx_toys_category ON toys(category_id);
CREATE INDEX idx_toys_owner    ON toys(owner_id);
GO

-- ---------------------------------------------------------
-- 4. BẢNG BORROW_REQUESTS
-- ---------------------------------------------------------
CREATE TABLE borrow_requests (
    request_id            INT IDENTITY(1,1) PRIMARY KEY,
    toy_id                INT NOT NULL,
    borrower_id           INT NOT NULL,
    owner_id              INT NOT NULL,
    request_date          DATETIME NOT NULL DEFAULT GETDATE(),
    borrow_date           DATE NULL,
    expected_return_date  DATE NULL,
    actual_return_date    DATE NULL,
    status  VARCHAR(12) NOT NULL DEFAULT 'PENDING'
            CHECK (status IN ('PENDING','APPROVED','REJECTED','BORROWING','RETURNED','CANCELLED')),
    -- Không có giá trị 'OVERDUE' trong cột này — quá hạn được tính động qua view v_borrow_requests_status
    note                  NVARCHAR(255) NULL,
    created_at            DATETIME NOT NULL DEFAULT GETDATE(),
    updated_at            DATETIME NOT NULL DEFAULT GETDATE(),

    CONSTRAINT fk_br_toy      FOREIGN KEY (toy_id)      REFERENCES toys(toy_id),
    CONSTRAINT fk_br_borrower FOREIGN KEY (borrower_id) REFERENCES users(user_id),
    CONSTRAINT fk_br_owner    FOREIGN KEY (owner_id)    REFERENCES users(user_id),
    CONSTRAINT chk_dates CHECK (
        expected_return_date IS NULL OR borrow_date IS NULL
        OR expected_return_date >= borrow_date
    ),
    CONSTRAINT chk_not_self_borrow CHECK (borrower_id <> owner_id)
);
GO

CREATE INDEX idx_br_status   ON borrow_requests(status);
CREATE INDEX idx_br_borrower ON borrow_requests(borrower_id);
CREATE INDEX idx_br_owner    ON borrow_requests(owner_id);
CREATE INDEX idx_br_toy      ON borrow_requests(toy_id);
GO

-- ---------------------------------------------------------
-- 5. BẢNG REVIEWS
-- ---------------------------------------------------------
CREATE TABLE reviews (
    review_id     INT IDENTITY(1,1) PRIMARY KEY,
    request_id    INT NOT NULL,
    reviewer_id   INT NOT NULL,
    reviewed_id   INT NOT NULL,
    rating        TINYINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment       NVARCHAR(255) NULL,
    created_at    DATETIME NOT NULL DEFAULT GETDATE(),

    CONSTRAINT fk_rv_request  FOREIGN KEY (request_id)  REFERENCES borrow_requests(request_id),
    CONSTRAINT fk_rv_reviewer FOREIGN KEY (reviewer_id) REFERENCES users(user_id),
    CONSTRAINT fk_rv_reviewed FOREIGN KEY (reviewed_id) REFERENCES users(user_id),
    CONSTRAINT uq_review_once UNIQUE (request_id, reviewer_id)  -- mỗi người chỉ đánh giá 1 lần / giao dịch
);
GO

-- ---------------------------------------------------------
-- 6. BẢNG NOTIFICATIONS
-- ---------------------------------------------------------
CREATE TABLE notifications (
    notification_id INT IDENTITY(1,1) PRIMARY KEY,
    user_id         INT NOT NULL,
    title           NVARCHAR(150) NULL,
    content         NVARCHAR(255) NOT NULL,
    type            VARCHAR(50) NULL,   -- REQUEST_NEW, REQUEST_APPROVED, REQUEST_REJECTED, RETURN_CONFIRMED...
    is_read         BIT NOT NULL DEFAULT 0,
    created_at      DATETIME NOT NULL DEFAULT GETDATE(),

    CONSTRAINT fk_noti_user FOREIGN KEY (user_id) REFERENCES users(user_id)
);
GO

CREATE INDEX idx_noti_user_read ON notifications(user_id, is_read);
GO

-- ---------------------------------------------------------
-- 7. BẢNG REPORTS (mở rộng, không bắt buộc)
-- ---------------------------------------------------------
CREATE TABLE reports (
    report_id         INT IDENTITY(1,1) PRIMARY KEY,
    reporter_id       INT NOT NULL,
    reported_toy_id   INT NULL,
    reported_user_id  INT NULL,
    reason            NVARCHAR(255) NOT NULL,
    status            VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING','RESOLVED','REJECTED')),
    created_at        DATETIME NOT NULL DEFAULT GETDATE(),

    CONSTRAINT fk_rp_reporter FOREIGN KEY (reporter_id)      REFERENCES users(user_id),
    CONSTRAINT fk_rp_toy      FOREIGN KEY (reported_toy_id)  REFERENCES toys(toy_id),
    CONSTRAINT fk_rp_user     FOREIGN KEY (reported_user_id) REFERENCES users(user_id),
    CONSTRAINT chk_report_target CHECK (
        reported_toy_id IS NOT NULL OR reported_user_id IS NOT NULL
    )
);
GO

-- =========================================================
-- VIEW: tính trạng thái hiệu lực của phiếu mượn (OVERDUE động)
-- Quy tắc 4: không lưu OVERDUE cứng, tính lúc truy vấn
-- =========================================================
CREATE VIEW v_borrow_requests_status AS
SELECT
    br.*,
    CASE
        WHEN br.status = 'BORROWING'
             AND br.expected_return_date IS NOT NULL
             AND br.expected_return_date < CAST(GETDATE() AS DATE)
        THEN 'OVERDUE'
        ELSE br.status
    END AS effective_status
FROM borrow_requests br;
GO

-- =========================================================
-- TRIGGERS: ép quy tắc nghiệp vụ ở tầng dữ liệu
-- SQL Server không có BEFORE trigger -> dùng AFTER + ROLLBACK khi vi phạm,
-- và xử lý theo TẬP HỢP (dùng bảng ảo inserted/deleted) chứ không per-row như MySQL.
-- =========================================================

-- Quy tắc 1 + 8: chặn gửi yêu cầu khi đồ chơi không sẵn sàng, chặn tự mượn đồ mình
CREATE TRIGGER trg_br_after_insert
ON borrow_requests
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1 FROM inserted i
        JOIN toys t ON t.toy_id = i.toy_id
        WHERE t.status <> 'AVAILABLE'
    )
    BEGIN
        RAISERROR (N'Đồ chơi hiện không sẵn sàng để mượn', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    -- Kiểm tra tự mượn dựa trên CHỦ THẬT của toy_id (toys.owner_id), không dựa vào owner_id
    -- app gửi lên - vì nếu app lỡ gửi sai owner_id, check dựa trên giá trị đó sẽ bị qua mặt.
    IF EXISTS (
        SELECT 1 FROM inserted i
        JOIN toys t ON t.toy_id = i.toy_id
        WHERE i.borrower_id = t.owner_id
    )
    BEGIN
        RAISERROR (N'Không thể tự mượn đồ chơi của chính mình', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    -- owner_id là dữ liệu denormalize (copy từ toys.owner_id) để đỡ join khi query.
    -- KHÔNG tin owner_id do tầng ứng dụng gửi lên — luôn đồng bộ lại đúng chủ thật của toy_id,
    -- tránh trường hợp code Java gửi sai owner_id làm giao dịch ghi nhận nhầm chủ sở hữu.
    UPDATE br
    SET owner_id = t.owner_id
    FROM borrow_requests br
    JOIN inserted i ON br.request_id = i.request_id
    JOIN toys t ON t.toy_id = i.toy_id
    WHERE br.owner_id <> t.owner_id;
END;
GO

-- Quy tắc 1 + 2 + 3 + 6: kiểm soát các bước chuyển trạng thái + hiệu ứng phụ (khoá/mở đồ chơi, auto-reject)
CREATE TRIGGER trg_br_after_update
ON borrow_requests
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Chặn sửa phiếu đã ở trạng thái cuối
    IF EXISTS (
        SELECT 1 FROM inserted i JOIN deleted d ON i.request_id = d.request_id
        WHERE d.status IN ('REJECTED','RETURNED','CANCELLED') AND i.status <> d.status
    )
    BEGIN
        RAISERROR (N'Phiếu mượn đã ở trạng thái cuối, không thể thay đổi', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    -- Từ APPROVED: chỉ được BORROWING (không huỷ / từ chối lại)
    IF EXISTS (
        SELECT 1 FROM inserted i JOIN deleted d ON i.request_id = d.request_id
        WHERE d.status = 'APPROVED' AND i.status NOT IN ('APPROVED','BORROWING')
    )
    BEGIN
        RAISERROR (N'Yêu cầu đã duyệt: không thể huỷ hoặc từ chối lại', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    -- Từ BORROWING: chỉ được RETURNED
    IF EXISTS (
        SELECT 1 FROM inserted i JOIN deleted d ON i.request_id = d.request_id
        WHERE d.status = 'BORROWING' AND i.status NOT IN ('BORROWING','RETURNED')
    )
    BEGIN
        RAISERROR (N'Chuyển trạng thái không hợp lệ từ BORROWING', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    -- Tự set ngày trả thực tế khi chuyển RETURNED nếu chưa có
    UPDATE br
    SET actual_return_date = CAST(GETDATE() AS DATE), updated_at = GETDATE()
    FROM borrow_requests br
    JOIN inserted i ON br.request_id = i.request_id
    WHERE i.status = 'RETURNED' AND br.actual_return_date IS NULL;

    -- Khi 1 phiếu được duyệt: khoá đồ chơi + tự động từ chối các phiếu PENDING khác cùng đồ chơi
    UPDATE t
    SET status = 'BORROWED'
    FROM toys t
    JOIN inserted i ON t.toy_id = i.toy_id
    JOIN deleted  d ON i.request_id = d.request_id
    WHERE i.status = 'APPROVED' AND d.status = 'PENDING';

    UPDATE br
    SET status = 'REJECTED'
    FROM borrow_requests br
    JOIN inserted i ON br.toy_id = i.toy_id AND br.request_id <> i.request_id
    JOIN deleted  d ON i.request_id = d.request_id
    WHERE i.status = 'APPROVED' AND d.status = 'PENDING' AND br.status = 'PENDING';

    -- Khi phiếu RETURNED: mở lại đồ chơi
    UPDATE t
    SET status = 'AVAILABLE'
    FROM toys t
    JOIN inserted i ON t.toy_id = i.toy_id
    JOIN deleted  d ON i.request_id = d.request_id
    WHERE i.status = 'RETURNED' AND d.status = 'BORROWING' AND t.status = 'BORROWED';
END;
GO

-- Quy tắc 6: đồ chơi đang có phiếu chưa kết thúc thì không cho xoá cứng
CREATE TRIGGER trg_toys_instead_delete
ON toys
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1 FROM deleted d
        JOIN borrow_requests br ON br.toy_id = d.toy_id
        WHERE br.status IN ('PENDING','APPROVED','BORROWING')
    )
    BEGIN
        RAISERROR (N'Không thể xoá: đồ chơi đang có giao dịch chưa hoàn tất', 16, 1);
        RETURN;
    END

    DELETE FROM toys WHERE toy_id IN (SELECT toy_id FROM deleted);
END;
GO

-- Quy tắc 5: chỉ đánh giá khi phiếu đã RETURNED, người đánh giá/được đánh giá phải đúng phiếu đó
CREATE TRIGGER trg_reviews_after_insert
ON reviews
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1 FROM inserted i
        JOIN borrow_requests br ON br.request_id = i.request_id
        WHERE br.status <> 'RETURNED'
    )
    BEGIN
        RAISERROR (N'Chỉ đánh giá được sau khi giao dịch đã hoàn tất (RETURNED)', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    IF EXISTS (
        SELECT 1 FROM inserted i
        JOIN borrow_requests br ON br.request_id = i.request_id
        WHERE NOT (
            (i.reviewer_id = br.borrower_id AND i.reviewed_id = br.owner_id) OR
            (i.reviewer_id = br.owner_id AND i.reviewed_id = br.borrower_id)
        )
    )
    BEGIN
        RAISERROR (N'Người đánh giá / được đánh giá không thuộc giao dịch này', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END;
GO

-- Quy tắc 7: khi tài khoản chuyển sang LOCKED -> tự ẩn các đồ chơi đang AVAILABLE
CREATE TRIGGER trg_users_after_update
ON users
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE t
    SET status = 'HIDDEN'
    FROM toys t
    JOIN inserted i ON t.owner_id = i.user_id
    JOIN deleted  d ON i.user_id = d.user_id
    WHERE i.status = 'LOCKED' AND d.status = 'ACTIVE' AND t.status = 'AVAILABLE';

    UPDATE u SET updated_at = GETDATE()
    FROM users u JOIN inserted i ON u.user_id = i.user_id;
END;
GO

-- =========================================================
-- DỮ LIỆU MẪU
-- Chuỗi tiếng Việt PHẢI có tiền tố N'...' vì cột dùng NVARCHAR (Unicode)
-- =========================================================
INSERT INTO categories (category_name, description) VALUES
(N'Đồ chơi vận động',      N'Xe đạp, xe chòi chân, bóng...'),
(N'Đồ chơi trí tuệ',       N'Lego, xếp hình, board game...'),
(N'Đồ chơi mô hình',       N'Búp bê, siêu nhân, thú nhồi bông...'),
(N'Sách/Đồ chơi giáo dục', N'Sách vải, thẻ học, đồ chơi STEM...');
GO

-- Mật khẩu bên dưới là placeholder, thay bằng chuỗi băm (BCrypt) thật khi code
INSERT INTO users (username, password, full_name, email, phone, role, status) VALUES
('admin',  '$2a$hashed_admin_pw', N'Quản trị viên',     'admin@toyshare.vn', '0900000000', 'ADMIN', 'ACTIVE'),
('khuepm', '$2a$hashed_pw',       N'Phạm Minh Khuê',    'khue@example.com',  '0900000001', 'USER',  'ACTIVE'),
('anhdv',  '$2a$hashed_pw',       N'Đoàn Vân Anh',      'anh@example.com',   '0900000002', 'USER',  'ACTIVE'),
('sontn',  '$2a$hashed_pw',       N'Trịnh Ngọc Sơn',    'son@example.com',   '0900000003', 'USER',  'ACTIVE');
GO

INSERT INTO toys (owner_id, category_id, toy_name, description, age_range, condition_status, status) VALUES
(2, 1, N'Xe chòi chân hình khủng long', N'Còn mới, dùng 2 tháng', N'2-4 tuổi', 'NEW',  'AVAILABLE'),
(3, 2, N'Bộ Lego Classic 500 mảnh',     N'Đầy đủ mảnh, có hộp',   N'5-10 tuổi','GOOD', 'AVAILABLE');
GO

