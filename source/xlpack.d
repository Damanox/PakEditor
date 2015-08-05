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
	
	public struct File
    {
        public uint pntr;
        public uint cnt;
        public uint base;
        public uint flag;
        public uint file;
        public uint charbuf;
        public uint bufsize;
        public uint tmpfname;
    }

    public struct FileInfo
    {
        public uint dwFileAttributes;
        public ulong ftCreationTime;
        public ulong ftLastAccessTime;
        public ulong ftLastWriteTime;
        public uint dwVolumeSerialNumber;
        public uint nFileSizeHigh;
        public uint nFileSizeLow;
        public uint nNumberOfLinks;
        public uint nFileIndexHigh;
        public uint nFileIndexLow;
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
    static xlpack.File* FOpen(const (char)*, const (char)*);
    static void FClose(ref xlpack.File*);
    pragma(mangle, "?FGetMD5@@YA_NPAUFile@@QAD@Z")
    static bool FGetMD5(xlpack.File*, ubyte[16]*);
    static bool FGetStat(xlpack.File*, xlpack.FileInfo*);
    static void DestroyFileSystem();
    static bool FDelete(const (char)*);
    static bool DeleteDir(const (char)*);
    static bool IsFileExist(const (char)*);
    static bool IsDirectory(afs_finddata*);
    static void* Mount(const (char)*, const (char)*, bool);
    static void* SetFileLogHandler(const (char)*, lf);
    static bool Unmount(const (char)*);
}