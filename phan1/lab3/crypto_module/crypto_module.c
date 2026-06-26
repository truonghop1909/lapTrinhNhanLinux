#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/fs.h>
#include <linux/proc_fs.h>
#include <linux/uaccess.h>
#include <linux/slab.h>
#include <linux/vmalloc.h>
#include <linux/mutex.h>

#define PROC_NAME "xor3"
#define PROC_RAW  "xor3_raw"
#define BUFFER_SIZE 128

/*
 * Khóa XOR.
 * Ví dụ:
 * 'A' XOR 0x5A tạo ra dữ liệu đã mã hóa.
 * Dữ liệu mã hóa XOR lại với 0x5A sẽ trở về 'A'.
 */
static unsigned char key = 0x5A;

/* Buffer chứa dữ liệu đã được mã hóa */
static char *buffer;

/* Số byte dữ liệu thực tế đang có trong buffer */
static size_t data_len;

/* Hai file trong /proc */
static struct proc_dir_entry *proc_entry;
static struct proc_dir_entry *proc_raw_entry;

/* Bảo vệ buffer khi có nhiều tiến trình đọc và ghi đồng thời */
static DEFINE_MUTEX(buffer_lock);

/*
 * Đọc dữ liệu đã giải mã từ /proc/xor3.
 */
static ssize_t proc_read(struct file *file,
                         char __user *user_buf,
                         size_t count,
                         loff_t *off)
{
    char *tmp;
    size_t bytes_to_read;
    size_t i;

    /*
     * Nếu offset đã vượt quá độ dài dữ liệu,
     * quá trình đọc đã kết thúc.
     */
    if (*off >= data_len)
        return 0;

    bytes_to_read = count;

    if (bytes_to_read > data_len - *off)
        bytes_to_read = data_len - *off;

    tmp = kmalloc(bytes_to_read, GFP_KERNEL);
    if (!tmp)
        return -ENOMEM;

    mutex_lock(&buffer_lock);

    /*
     * Giải mã dữ liệu:
     * plaintext = ciphertext XOR key
     */
    for (i = 0; i < bytes_to_read; i++)
        tmp[i] = buffer[*off + i] ^ key;

    mutex_unlock(&buffer_lock);

    if (copy_to_user(user_buf, tmp, bytes_to_read)) {
        kfree(tmp);
        return -EFAULT;
    }

    kfree(tmp);

    *off += bytes_to_read;

    return bytes_to_read;
}

/*
 * Ghi dữ liệu vào /proc/xor3.
 * Dữ liệu sẽ được XOR trước khi lưu vào buffer.
 */
static ssize_t proc_write(struct file *file,
                          const char __user *user_buf,
                          size_t count,
                          loff_t *off)
{
    char *tmp;
    size_t write_len;
    size_t i;

    if (count == 0)
        return 0;

    /*
     * Cấp phát count + 1 byte để có chỗ chứa ký tự kết thúc chuỗi.
     */
    tmp = kmalloc(count + 1, GFP_KERNEL);
    if (!tmp)
        return -ENOMEM;

    if (copy_from_user(tmp, user_buf, count)) {
        kfree(tmp);
        return -EFAULT;
    }

    tmp[count] = '\0';
    write_len = count;

    /*
     * Lệnh echo thường tự thêm '\n'.
     * Loại bỏ ký tự xuống dòng để dữ liệu lưu đúng nội dung.
     */
    if (write_len > 0 && tmp[write_len - 1] == '\n')
        write_len--;

    /*
     * Phải dành một byte cuối buffer cho ký tự '\0'.
     */
    if (write_len >= BUFFER_SIZE) {
        kfree(tmp);
        return -EINVAL;
    }

    mutex_lock(&buffer_lock);

    memset(buffer, 0, BUFFER_SIZE);

    /*
     * Mã hóa dữ liệu bằng XOR.
     */
    for (i = 0; i < write_len; i++)
        buffer[i] = tmp[i] ^ key;

    data_len = write_len;
    buffer[data_len] = '\0';

    mutex_unlock(&buffer_lock);

    kfree(tmp);

    /*
     * Đặt lại offset sau mỗi lần ghi.
     */
    *off = 0;

    pr_info("crypto_module: wrote %zu bytes, stored %zu bytes\n",
            count, write_len);

    /*
     * Hàm write phải trả lại số byte người dùng đã gửi,
     * kể cả ký tự xuống dòng đã được loại bỏ khi lưu.
     */
    return count;
}

/*
 * Đọc dữ liệu mã hóa thô từ /proc/xor3_raw.
 */
static ssize_t raw_read(struct file *file,
                        char __user *user_buf,
                        size_t count,
                        loff_t *off)
{
    char *tmp;
    size_t bytes_to_read;

    if (*off >= data_len)
        return 0;

    bytes_to_read = count;

    if (bytes_to_read > data_len - *off)
        bytes_to_read = data_len - *off;

    tmp = kmalloc(bytes_to_read, GFP_KERNEL);
    if (!tmp)
        return -ENOMEM;

    mutex_lock(&buffer_lock);

    memcpy(tmp, buffer + *off, bytes_to_read);

    mutex_unlock(&buffer_lock);

    if (copy_to_user(user_buf, tmp, bytes_to_read)) {
        kfree(tmp);
        return -EFAULT;
    }

    kfree(tmp);

    *off += bytes_to_read;

    return bytes_to_read;
}

/*
 * Các thao tác dành cho /proc/xor3.
 */
static const struct proc_ops proc_fops = {
    .proc_read = proc_read,
    .proc_write = proc_write,
    .proc_lseek = default_llseek,
};

/*
 * Các thao tác dành cho /proc/xor3_raw.
 */
static const struct proc_ops raw_fops = {
    .proc_read = raw_read,
    .proc_lseek = default_llseek,
};

/*
 * Hàm được gọi khi nạp module bằng insmod.
 */
static int __init crypto_init(void)
{
    buffer = vmalloc(BUFFER_SIZE);
    if (!buffer) {
        pr_err("crypto_module: cannot allocate buffer\n");
        return -ENOMEM;
    }

    memset(buffer, 0, BUFFER_SIZE);
    data_len = 0;

    proc_entry = proc_create(PROC_NAME,
                             0666,
                             NULL,
                             &proc_fops);

    if (!proc_entry) {
        pr_err("crypto_module: cannot create /proc/%s\n",
               PROC_NAME);

        vfree(buffer);
        buffer = NULL;

        return -ENOMEM;
    }

    proc_raw_entry = proc_create(PROC_RAW,
                                 0444,
                                 NULL,
                                 &raw_fops);

    if (!proc_raw_entry) {
        pr_err("crypto_module: cannot create /proc/%s\n",
               PROC_RAW);

        proc_remove(proc_entry);
        proc_entry = NULL;

        vfree(buffer);
        buffer = NULL;

        return -ENOMEM;
    }

    pr_info("crypto_module: loaded successfully\n");
    pr_info("crypto_module: XOR key = 0x%02x\n", key);
    pr_info("crypto_module: created /proc/%s\n", PROC_NAME);
    pr_info("crypto_module: created /proc/%s\n", PROC_RAW);

    return 0;
}

/*
 * Hàm được gọi khi gỡ module bằng rmmod.
 */
static void __exit crypto_exit(void)
{
    if (proc_raw_entry) {
        proc_remove(proc_raw_entry);
        proc_raw_entry = NULL;
    }

    if (proc_entry) {
        proc_remove(proc_entry);
        proc_entry = NULL;
    }

    if (buffer) {
        vfree(buffer);
        buffer = NULL;
    }

    data_len = 0;

    pr_info("crypto_module: unloaded successfully\n");
}

module_init(crypto_init);
module_exit(crypto_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Hop");
MODULE_DESCRIPTION("Simple XOR encryption and decryption Linux kernel module");
MODULE_VERSION("1.0");