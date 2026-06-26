#include <linux/init.h>
#include <linux/module.h>
#include <linux/proc_fs.h>
#include <linux/uaccess.h>
#include <linux/slab.h>
#include <linux/vmalloc.h>
#include <linux/string.h>

#define PROC_NAME "xor"
#define BUFFER_SIZE 128

static unsigned char key = 0x5A;
static char *buffer;
static size_t data_len;  // lưu kích thước dữ liệu thực tế
static struct proc_dir_entry *proc_entry;

static ssize_t proc_read(struct file *file, char __user *user_buf, size_t count, loff_t *off)
{
    if (*off >= data_len)
        return 0;
    if (count > data_len - *off)
        count = data_len - *off;

    // Tạo bản sao đã giải mã
    char *tmp = kmalloc(count + 1, GFP_KERNEL);
    if (!tmp)
        return -ENOMEM;

    int i;
    for (i = 0; i < count; i++)
        tmp[i] = buffer[*off + i] ^ key;
    tmp[count] = '\0';

    if (copy_to_user(user_buf, tmp, count)) {
        kfree(tmp);
        return -EFAULT;
    }
    kfree(tmp);
    *off += count;
    return count;
}

static ssize_t proc_write(struct file *file, const char __user *user_buf, size_t count, loff_t *off)
{
    if (count >= BUFFER_SIZE)
        return -EINVAL;

    char *tmp = kmalloc(count + 1, GFP_KERNEL);
    if (!tmp)
        return -ENOMEM;

    if (copy_from_user(tmp, user_buf, count)) {
        kfree(tmp);
        return -EFAULT;
    }
    tmp[count] = '\0';

    // Mã hóa và lưu vào buffer
    int i;
    for (i = 0; i < count; i++)
        buffer[i] = tmp[i] ^ key;
    data_len = count;          // cập nhật kích thước
    buffer[count] = '\0';      // đặt null terminator

    kfree(tmp);
    *off = 0;                  // reset offset khi ghi
    return count;
}

static const struct proc_ops proc_fops = {
    .proc_read = proc_read,
    .proc_write = proc_write,
};

static int __init crypto_init(void)
{
    buffer = vmalloc(BUFFER_SIZE);
    if (!buffer)
        return -ENOMEM;
    memset(buffer, 0, BUFFER_SIZE);
    data_len = 0;

    proc_entry = proc_create(PROC_NAME, 0666, NULL, &proc_fops);
    if (!proc_entry) {
        vfree(buffer);
        return -ENOMEM;
    }

    printk(KERN_INFO "XOR crypto module loaded (key=0x%02x)\n", key);
    return 0;
}

static void __exit crypto_exit(void)
{
    proc_remove(proc_entry);
    vfree(buffer);
    printk(KERN_INFO "XOR crypto module unloaded\n");
}

module_init(crypto_init);
module_exit(crypto_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Your Name");
MODULE_DESCRIPTION("Simple XOR encryption/decryption in kernel");