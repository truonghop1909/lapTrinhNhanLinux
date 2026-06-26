#include <linux/init.h>
#include <linux/module.h>
#include <linux/proc_fs.h>
#include <linux/uaccess.h>
#include <linux/slab.h>
#include <linux/seq_file.h>
#include <linux/mutex.h>
#include <linux/time.h>

#define PROC_NAME "mymodule"
#define PROC_STATUS "mymodule_status"
#define BUFFER_SIZE 512

static char *kernel_buffer;
static struct proc_dir_entry *proc_entry;
static struct proc_dir_entry *status_entry;
static DEFINE_MUTEX(buffer_mutex);

static atomic_t read_count = ATOMIC_INIT(0);
static atomic_t write_count = ATOMIC_INIT(0);
static struct timespec64 last_write_time;

/* ===================== /proc/mymodule ===================== */
static ssize_t proc_read(struct file *file, char __user *user_buf, size_t count, loff_t *off) {
    size_t len;
    char *local_buf;
    int ret;

    mutex_lock(&buffer_mutex);
    len = strlen(kernel_buffer);
    local_buf = kmalloc(len + 1, GFP_KERNEL);
    if (!local_buf) {
        mutex_unlock(&buffer_mutex);
        return -ENOMEM;
    }
    strcpy(local_buf, kernel_buffer);
    mutex_unlock(&buffer_mutex);

    atomic_inc(&read_count);

    if (*off >= len) {
        kfree(local_buf);
        return 0;
    }
    if (count > len - *off)
        count = len - *off;

    ret = copy_to_user(user_buf, local_buf + *off, count);
    kfree(local_buf);
    if (ret)
        return -EFAULT;

    *off += count;
    return count;
}

static ssize_t proc_write(struct file *file, const char __user *user_buf, size_t count, loff_t *off) {
    char *cmd;
    int ret = count;

    if (count > BUFFER_SIZE - 1)
        return -EINVAL;

    cmd = kmalloc(count + 1, GFP_KERNEL);
    if (!cmd)
        return -ENOMEM;

    if (copy_from_user(cmd, user_buf, count)) {
        kfree(cmd);
        return -EFAULT;
    }
    cmd[count] = '\0';

    /* Xóa ký tự newline cuối nếu có */
    if (count > 0 && cmd[count-1] == '\n')
        cmd[count-1] = '\0';

    mutex_lock(&buffer_mutex);

    /* Xử lý lệnh */
    if (strcmp(cmd, "clear") == 0) {
        strcpy(kernel_buffer, "");
        ret = count;
        goto out;
    }
    if (strcmp(cmd, "reset") == 0) {
        strcpy(kernel_buffer, "Default message from kernel\n");
        ret = count;
        goto out;
    }
    if (strncmp(cmd, "set ", 4) == 0) {
        strncpy(kernel_buffer, cmd + 4, BUFFER_SIZE - 1);
        kernel_buffer[BUFFER_SIZE - 1] = '\0';
        ret = count;
        goto out;
    }
    if (strcmp(cmd, "status") == 0) {
        char tmp[128];
        snprintf(tmp, sizeof(tmp),
                 "Reads: %d\nWrites: %d\nLast write: %lld.%09ld\n",
                 atomic_read(&read_count),
                 atomic_read(&write_count),
                 last_write_time.tv_sec,
                 last_write_time.tv_nsec);
        strncpy(kernel_buffer, tmp, BUFFER_SIZE - 1);
        kernel_buffer[BUFFER_SIZE - 1] = '\0';
        ret = count;
        goto out;
    }

    /* Mặc định: ghi nội dung thường */
    strncpy(kernel_buffer, cmd, BUFFER_SIZE - 1);
    kernel_buffer[BUFFER_SIZE - 1] = '\0';
    ret = count;

out:
    atomic_inc(&write_count);
    ktime_get_real_ts64(&last_write_time);
    mutex_unlock(&buffer_mutex);
    kfree(cmd);
    return ret;
}

static const struct proc_ops proc_fops = {
    .proc_read = proc_read,
    .proc_write = proc_write,
};

/* ===================== /proc/mymodule_status (seq_file) ===================== */
static int status_show(struct seq_file *m, void *v) {
    seq_printf(m, "=== Module Status ===\n");
    seq_printf(m, "Read count:  %d\n", atomic_read(&read_count));
    seq_printf(m, "Write count: %d\n", atomic_read(&write_count));
    seq_printf(m, "Buffer size: %d\n", BUFFER_SIZE);
    seq_printf(m, "Last write:  %lld.%09ld\n",
               last_write_time.tv_sec, last_write_time.tv_nsec);
    seq_printf(m, "Current content:\n%s\n", kernel_buffer);
    return 0;
}

static int status_open(struct inode *inode, struct file *file) {
    return single_open(file, status_show, NULL);
}

static const struct proc_ops status_fops = {
    .proc_open = status_open,
    .proc_read = seq_read,
    .proc_lseek = seq_lseek,
    .proc_release = single_release,
};

/* ===================== Init / Exit ===================== */
static int __init proc_init(void) {
    kernel_buffer = kmalloc(BUFFER_SIZE, GFP_KERNEL);
    if (!kernel_buffer)
        return -ENOMEM;

    strcpy(kernel_buffer, "Default message from kernel\n");
    ktime_get_real_ts64(&last_write_time);

    proc_entry = proc_create(PROC_NAME, 0666, NULL, &proc_fops);
    if (!proc_entry) {
        kfree(kernel_buffer);
        return -ENOMEM;
    }

    status_entry = proc_create(PROC_STATUS, 0444, NULL, &status_fops);
    if (!status_entry) {
        proc_remove(proc_entry);
        kfree(kernel_buffer);
        return -ENOMEM;
    }

    printk(KERN_INFO "/proc/%s and /proc/%s created\n", PROC_NAME, PROC_STATUS);
    return 0;
}

static void __exit proc_exit(void) {
    proc_remove(status_entry);
    proc_remove(proc_entry);
    kfree(kernel_buffer);
    printk(KERN_INFO "/proc/%s and /proc/%s removed\n", PROC_NAME, PROC_STATUS);
}

module_init(proc_init);
module_exit(proc_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Your Name");
MODULE_DESCRIPTION("Advanced procfs module with commands and status");