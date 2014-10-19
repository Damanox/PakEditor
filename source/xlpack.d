module xlpack;

struct XlEntry
{
    string name;
    bool isDir;
}

extern (C++)
{
    public struct afs_finddata
    {
        public long data0;
        public long data1;
        public long data2;
        public long data3;
        public long data4;
        public long data5;
        public long data6;
        public long data7;
        public long data8;
        public long data9;
        public long data10;
    }
    
    alias void function (const (char)*, ...) lf;

	static bool CreateFileSystem();
    static bool ApplyPatchPak(const (char)*, const (char)*);
    static bool Copy(const (char)*, const (char)*);
    static bool CopyDir(const (char)*, const (char)*);
    static void DestroyFileLogHandler(void*);
    static int FindClose(int);
    static int FindFirst (const (char)*, afs_finddata*);
    static int FindNext(int, afs_finddata*);
    static const(char)* GetFileName(const (afs_finddata)*);
    static void DestroyFileSystem();
    static bool FDelete(const (char)*);
    static bool DeleteDir(const (char)*);
    static bool IsFileExist(const (char)*);
    static bool IsDirectory(afs_finddata*);
    static void* Mount(const (char)*, const (char)*, bool);
    static void* SetFileLogHandler(const (char)*, lf);
    static bool Unmount(const (char)*);
}