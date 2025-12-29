--- a/fs/proc/task_mmu.c	2024-12-17 11:21:16.646581300 -0500
+++ b/fs/proc/task_mmu.c	2024-12-17 11:35:36.873887048 -0500
@@ -416,6 +416,23 @@
 extern void susfs_sus_ino_for_show_map_vma(unsigned long ino, dev_t *out_dev, unsigned long *out_ino);
 #endif
 
+static void show_vma_header_prefix_fake(struct seq_file *m,
+					unsigned long start, unsigned long end,
+					vm_flags_t flags, unsigned long long pgoff,
+					dev_t dev, unsigned long ino)
+{
+	seq_setwidth(m, 25 + sizeof(void *) * 6 - 1);
+	seq_printf(m, "%08lx-%08lx %c%c%c%c %08llx %02x:%02x %lu ",
+			start,
+			end,
+			flags & VM_READ ? 'r' : '-',
+			flags & VM_WRITE ? 'w' : '-',
+			flags & VM_EXEC ? '-' : '-',
+			flags & VM_MAYSHARE ? 's' : 'p',
+			pgoff,
+			MAJOR(dev), MINOR(dev), ino);
+}
+
 static void
 show_map_vma(struct seq_file *m, struct vm_area_struct *vma)
 {
@@ -427,6 +444,7 @@
 	unsigned long start, end;
 	dev_t dev = 0;
 	const char *name = NULL;
+	struct dentry *dentry;
 
 	if (file) {
 		struct inode *inode = file_inode(vma->vm_file);
@@ -442,6 +460,23 @@
 bypass_orig_flow:
 #endif
 		pgoff = ((loff_t)vma->vm_pgoff) << PAGE_SHIFT;
+		dentry = file->f_path.dentry;
+        if (dentry) {
+        	const char *path = (const char *)dentry->d_name.name; 
+            if (strstr(path, "lineage")) {
+			start = vma->vm_start;
+			end = vma->vm_end;
+			show_vma_header_prefix(m, start, end, flags, pgoff, dev, ino);
+			name = "/system/framework/framework-res.apk";
+			goto done;
+            }
+			if (strstr(path, "jit-zygote-cache")) { 
+			start = vma->vm_start;
+			end = vma->vm_end;
+			show_vma_header_prefix_fake(m, start, end, flags, pgoff, dev, ino);
+			goto bypass;
+            }
+        }
 	}
 
 	start = vma->vm_start;
@@ -449,6 +484,7 @@
 	if (show_vma_header_prefix(m, start, end, flags, pgoff, dev, ino))
 		return;
 
+	bypass:
 	/*
 	 * Print the dentry name for named mappings, and a
 	 * special [heap] marker for the heap:
--- a/fs/proc/base.c	2024-12-15 11:30:00.213422100 -0500
+++ b/fs/proc/base.c	2024-12-15 11:36:21.422813925 -0500
@@ -2229,11 +2229,17 @@
 
 	rc = -ENOENT;
 	vma = find_exact_vma(mm, vm_start, vm_end);
-	if (vma && vma->vm_file) {
-		*path = vma->vm_file->f_path;
-		path_get(path);
-		rc = 0;
-	}
+	if (vma) {
+        if (vma->vm_file) {
+            if (strstr(vma->vm_file->f_path.dentry->d_name.name, "lineage")) { 
+				rc = kern_path("/system/framework/framework-res.apk", LOOKUP_FOLLOW, path);
+			} else {
+				*path = vma->vm_file->f_path;
+				path_get(path);
+				rc = 0;
+            }
+        }
+    }
 	mmap_read_unlock(mm);
 
 out_mmput:
 
