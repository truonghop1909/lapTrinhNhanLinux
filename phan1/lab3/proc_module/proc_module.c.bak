#include <linux/init.h>
#include <linux/module.h>
#include <linux/proc_fs.h>
#include <linux/uaccess.h>
#include <linux/slab.h>

#define PROC_NAME "mymodule"
#define BUFFER_SIZE 256

static char *kernel_buffer;
static struct proc_dir_entry *proc_entry;

static ssize_t proc_read(struct file *file, char __user *user_buf, size_t count, loff_t *off) {
    size_t len = strlen(kernel_buffer);
    if (*off >= len)
        return 0;                      // EOF
    if (count > len - *off)
        count = len - *off;
    if (copy_to_user(user_buf, kernel_buffer + *off, count))
        return -EFAULT;
    *off += count;
    return count;
}

static ssize_t proc_write(struct file *file, const char __user *user_buf, size_t count, loff_t *off) {
    if (count >= BUFFER_SIZE)
        return -EINVAL;
    if (copy_from_user(kernel_buffer, user_buf, count))
        return -EFAULT;
    kernel_buffer[count] = '\0';
    return count;
}

static const struct proc_ops proc_fops = {
    .proc_read = proc_read,
    .proc_write = proc_write,
};

static int __init proc_init(void) {
    kernel_buffer = kmalloc(BUFFER_SIZE, GFP_KERNEL);
    if (!kernel_buffer)
        return -ENOMEM;
    strcpy(kernel_buffer, "Default message from kernel\n");
    proc_entry = proc_create(PROC_NAME, 0666, NULL, &proc_fops);
    if (!proc_entry) {
        kfree(kernel_buffer);
        return -ENOMEM;
    }
    printk(KERN_INFO "/proc/%s created\n", PROC_NAME);
    return 0;
}

static void __exit proc_exit(void) {
    proc_remove(proc_entry);
    kfree(kernel_buffer);
    printk(KERN_INFO "/proc/%s removed\n", PROC_NAME);
}

module_init(proc_init);
module_exit(proc_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Your Name");
MODULE_DESCRIPTION("Procfs module - read/write from userspace");