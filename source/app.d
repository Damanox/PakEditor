import std.stdio;
import std.conv;
import std.string;
import std.file;
import std.path;
import std.algorithm;
import std.process;
import core.thread;
import xlpack;
import dgui.all;
import dgui.layout.panel;
import dgui.layout.gridpanel;

class LoadTask : Thread
{
    private MainForm _main;
    private string _filename;

    this(MainForm main, string filename)
    {
        _main = main;
        _filename = filename;
        super(&run);
    }
    
private :
    void run()
    {
        mount(_filename);
        auto root = _main.fileTree.addNode("root");
        root.tag = true;
        auto entries = getDir("/master/");
        if(entries.length > 0)
            fillNode(entries, root);
        root.expand();
    }

    void mount(string filename)
    {
        if(_main.loaded)
        {
            Unmount("/master".toStringz());
            Unmount("/fs".toStringz());
        }
        if(!exists(filename) || !isFile(filename))
            return;
        _main.fileTree.clear();
        _main.logInfo("Монтирование /fs... ");
        Mount("/fs".toStringz(), dirName(filename).toStringz(), true);
        _main.logInfo("Выполнено!\r\n");
        _main.logInfo("Монтирование /master... ");
        Mount("/master".toStringz(), filename.toStringz(), true);
        _main.logInfo("Выполнено!\r\n");
        _main.loaded = true;
    }
}

class ExportTask : Thread
{
    private MainForm _main;
    private TreeNode _node;
    private string _path;
    
    this(MainForm main, TreeNode node, string path)
    {
        _main = main;
        _node = node;
        _path = path;
        super(&run);
    }
    
private :
    void run()
    {
        if(!_node.hasNodes)
        {
            auto flag = Copy(("/master/" ~ _path).toStringz(), ("/fs/export/" ~ _path).toStringz());
            _main.logInfo("File " ~ _node.text ~ (!flag ? " Not" : "") ~ " Copy!\r\n");
        }
        else
            exportDir(_path);
    }

    void exportDir(string parent)
    {
        auto entries = getDir("/master/" ~ parent ~ "/");
        foreach(entry; entries)
        {
            auto path = parent ~ "/" ~ entry.name;
            if(!entry.isDir)
            {
                auto flag = Copy(("/master/" ~ path).toStringz(), ("/fs/export/" ~ path).toStringz());
                _main.logInfo("File " ~ entry.name ~ (!flag ? " Not" : "") ~ " Copy!\r\n");
            }  
            else
                exportDir(path);             
        }
    }
}

class ImportTask : Thread
{
    private MainForm _main;
    private TreeNode _node;
    private string _path;
    
    this(MainForm main, TreeNode node, string path)
    {
        _main = main;
        _node = node;
        _path = path;
        super(&run);
    }
    
private :
    void run()
    {
        foreach(DirEntry entry; dirEntries(dirName(_main.filename) ~ "/import" ~ _path, SpanMode.shallow))
        {
            if(!entry.isDir)
            {
                auto flag = Copy(("/fs/import" ~ _path ~ "/" ~ entry.baseName).toStringz(), ("/master" ~ _path ~ "/" ~ entry.baseName).toStringz());
                _main.logInfo("File " ~ entry.baseName ~ (!flag ? " Not" : "") ~ " Copy!\r\n");
                if(flag && !_node.contains(entry.baseName))
                    _node.addNode(entry.baseName);
            }
            else
            {
                auto child = _node.addNode(entry.baseName);
                child.tag = true;
                importDir(_path ~ "/" ~ entry.baseName, child);
            }
        }
    }

    void importDir(string path, TreeNode node)
    {
        foreach(DirEntry entry; dirEntries(dirName(_main.filename) ~ "/import" ~ path, SpanMode.shallow))
        {
            if(!entry.isDir)
            {
                auto flag = Copy(("/fs/import" ~ path ~ "/" ~ entry.baseName).toStringz(), ("/master" ~ path ~ "/" ~ entry.baseName).toStringz());
                _main.logInfo("File " ~ entry.baseName ~ (!flag ? " Not" : "") ~ " Copy!\r\n");
                if(flag && !node.contains(entry.baseName))
                    node.addNode(entry.baseName);
            }
            else
            {
                auto child = node.addNode(entry.baseName);
                child.tag = true;
                importDir(path ~ "/" ~ entry.baseName, child);
            }
        }
    }
}


class ExpandTask : Thread
{
    private TreeNode _node;
    private string _path;
    
    this(TreeNode node, string path)
    {
        _node = node;
        _path = path;
        super(&run);
    }
    
private :
    void run()
    {
        auto entries = getDir(_path);
        if(entries.length > 0)
        {
            _node.removeNode(0);
            fillNode(entries, _node);
        }
        _node.expand();
    }
}

class DeleteTask : Thread
{
    private MainForm _main;
    private TreeNode _node;
    private string _path;
    
    this(MainForm main, TreeNode node, string path)
    {
        _main = main;
        _node = node;
        _path = path;
        super(&run);
    }
    
private :
    void run()
    {
        auto flag = false;
        if(!_node.hasNodes)
            flag = FDelete(("/master" ~ _path).toStringz());
        else
            flag = DeleteDir(("/master" ~ _path).toStringz());
        _main.logInfo("Удаление " ~ _node.text ~ (flag ? " успешно!\r\n" : " ошибка!\r\n"));
        if(flag)
        {
            _node.remove();
            _node.treeView.redraw();
        }
    }
}

class MainForm : Form
{
private:
    TextBox _logText;
    TextBox _fileText;
    TreeView _fileTree;
    Button _loadButton;
    Button _exportButton;
    Button _importButton;
    Button _editButton;
    Button _removeButton;
    bool _loaded;
    string _filename;
    Config _config;

    @property public bool loaded()
    {
        return _loaded;
    }

    @property public void loaded(bool value)
    {
        _loaded = value;
    }

    @property public string filename()
    {
        return _filename;
    }

    @property public TreeView fileTree()
    {
        return _fileTree;
    }

    public this()
    {
        text = "Archeage Pak Editor";
        size = Size(400, 600);
        startPosition = FormStartPosition.centerScreen;
        maximizeBox = false;
        minimizeBox = false;
        formBorderStyle = FormBorderStyle.fixedDialog;

        auto mainPanel = new GridPanel();
        mainPanel.dock = DockStyle.fill;
        mainPanel.parent = this;
        auto mainRow = mainPanel.addRow();
        mainRow.height = 320;
        auto logRow = mainPanel.addRow();
        logRow.marginTop = 4;
        logRow.height = 245;
        auto progressRow = mainPanel.addRow();
        progressRow.marginTop = 4;
        progressRow.height = 26;

        auto filePanel = new GridPanel();
        filePanel.dock = DockStyle.left;
        filePanel.width = 320;
        filePanel.height = 30;
        mainRow.addColumn(filePanel);
        auto fileRow = filePanel.addRow();
        fileRow.marginTop = 4;
        fileRow.height = 25;
        _fileText = new TextBox();
        _fileText.width = 270;
        _fileText.textChanged.attach(&onFilenameChanged);
        auto textColumn = fileRow.addColumn(_fileText);
        textColumn.marginLeft = 4;
        auto fileOpen = new Button();
        fileOpen.text = "..";
        fileOpen.width = 40;
        fileOpen.click.attach(&chooseFile);
        auto openColumn = fileRow.addColumn(fileOpen);
        openColumn.marginLeft = 4;
        auto treeRow = filePanel.addRow();
        treeRow.marginTop = 4;
        treeRow.height = 300;
        _fileTree = new TreeView();
        _fileTree.width = 310;
        _fileTree.treeNodeExpanding.attach(&openEntry);
        _fileTree.selectedNodeChanged.attach(&onSelectEntry);
        auto treeColumn = treeRow.addColumn(_fileTree);
        treeColumn.marginLeft = 4;

        _logText = new TextBox();
        _logText.width = 350;
        _logText.multiline = true;
        _logText.readOnly = true;
        _logText.scrollBars = true;
        auto logColumn = logRow.addColumn(_logText);
        logColumn.width = 386;
        logColumn.marginLeft = 4;

        auto buttonPanel = new GridPanel();
        buttonPanel.dock = DockStyle.right;
        buttonPanel.width = 65;
        buttonPanel.height = 150;
        mainRow.addColumn(buttonPanel).marginLeft = 10;
        auto loadRow = buttonPanel.addRow();
        loadRow.marginTop = 4;
        loadRow.height = 25;
        _loadButton = new Button();
        _loadButton.text = "Load";
        _loadButton.width = 60;
        _loadButton.enabled = false;
        _loadButton.click.attach(&loadFile);
        loadRow.addColumn(_loadButton);
        auto exportRow = buttonPanel.addRow();
        exportRow.marginTop = 4;
        exportRow.height = 25;
        _exportButton = new Button();
        _exportButton.text = "Export";
        _exportButton.width = 60;
        _exportButton.enabled = false;
        _exportButton.click.attach(&exportFile);
        exportRow.addColumn(_exportButton);
        auto importRow = buttonPanel.addRow();
        importRow.marginTop = 4;
        importRow.height = 25;
        _importButton = new Button();
        _importButton.text = "Import";
        _importButton.width = 60;
        _importButton.enabled = false;
        _importButton.click.attach(&importFile);
        importRow.addColumn(_importButton);
        auto editRow = buttonPanel.addRow();
        editRow.marginTop = 4;
        editRow.height = 25;
        _editButton = new Button();
        _editButton.text = "Edit";
        _editButton.width = 60;
        _editButton.enabled = false;
        _editButton.click.attach(&editFile);
        editRow.addColumn(_editButton);
        auto removeRow = buttonPanel.addRow();
        removeRow.marginTop = 4;
        removeRow.height = 25;
        _removeButton = new Button();
        _removeButton.text = "Remove";
        _removeButton.width = 60;
        _removeButton.enabled = false;
        _removeButton.click.attach(&removeFile);
        removeRow.addColumn(_removeButton);
    }

    override protected void onClose(EventArgs e)
    {
        destroy();
        super.onClose(e);
    }
    
    void init()
    {
        logInfo("Создание файловой системы... ");
        auto res = CreateFileSystem();
        if(res)
            logInfo("Выполнено!\r\n");
        else
            logInfo("Ошибка!\r\n");
        /*log("Подключение функции лога... ");
        SetFileLogHandler("LOG.log".toStringz(), &log);
        log("Выполнено!\n");*/
    }

    void destroy()
    {
        if(_loaded)
        {
            Unmount("/master".toStringz());
            Unmount("/fs".toStringz());
        }
        DestroyFileSystem();
    }

    void onFilenameChanged(Control sender, EventArgs e)
    {
        if(_fileText.textLength > 0 && !_loadButton.enabled)
            _loadButton.enabled = true;
        else if(_fileText.textLength == 0 && _loadButton.enabled)
            _loadButton.enabled = false;
    }

    void onSelectEntry(Control sender, TreeNodeChangedEventArgs e)
    {
        auto node = _fileTree.selectedNode;
        if(node is null)
        {
            _exportButton.enabled = false;
            _importButton.enabled = false;
            _editButton.enabled = false;
            _removeButton.enabled = false;
            return;
        }
        _exportButton.enabled = true;
        _removeButton.enabled = true;
        if(node.hasNodes)
        {
            _importButton.enabled = true;
            _editButton.enabled = false;
        }
        else
        {
            _importButton.enabled = false;
            _editButton.enabled = true;
        }
    }

    void chooseFile(Control sender, EventArgs e)
    {
        auto dialog = new FileBrowserDialog();
        dialog.browseMode = FileBrowseMode.open;
        dialog.showDialog();
        auto res = dialog.result;
        if(res.length == 0)
            return;
        _fileText.text = res;
        if(_fileText.textLength > 0 && !_loadButton.enabled)
            _loadButton.enabled = true;
        else if(_fileText.textLength == 0 && _loadButton.enabled)
            _loadButton.enabled = false;
    }

    void loadFile(Control sender, EventArgs e)
    {
        _filename = _fileText.text;
        auto task = new LoadTask(this, _filename);
        task.start();
    }

    void exportFile(Control sender, EventArgs e)
    {
        auto node = _fileTree.selectedNode;
        if(node is null)
            return;
        auto path = buildPath(node).chompPrefix("/root");
        auto task = new ExportTask(this, node, path);
        task.start();
    }

    void importFile(Control sender, EventArgs e)
    {
        auto node = _fileTree.selectedNode;
        if(node is null || !node.hasNodes)
            return;
        auto path = buildPath(node).chompPrefix("/root");
        auto task = new ImportTask(this, node, path);
        task.start();
    }

    void editFile(Control sender, EventArgs e)
    {
        auto node = _fileTree.selectedNode;
        if(node is null || node.hasNodes)
            return;
        auto path = buildPath(node).chompPrefix("/root");
        auto tempFile = "/fs/temp/" ~ path;
        auto flag = Copy(("/master/" ~ path).toStringz(), tempFile.toStringz());
        if(!flag)
            return;
        logInfo("Editing file " ~ baseName(path) ~ "\r\n");
        auto openPath = dirName(_filename) ~ "/temp" ~ path;
        execute(["notepad.exe", openPath]);
        auto flag1 = Copy(("/fs/temp/" ~ path).toStringz(), ("/master/" ~ path).toStringz());
        if(flag1)
            logInfo("File " ~ baseName(path) ~ " imported\r\n");
        else
            logInfo("Error on importing file " ~ baseName(path) ~ "\r\n");
        remove(openPath);
        rmdirRecurse(dirName(_filename) ~ "/temp");
    }

    void removeFile(Control sender, EventArgs e)
    {
        auto node = _fileTree.selectedNode;
        if(node is null)
            return;
        auto path = buildPath(node).chompPrefix("/root");
        auto task = new DeleteTask(this, node, path);
        task.start();
    }

    void openEntry(Control sender, CancelTreeNodeEventArgs e)
    {
        auto node = e.item;
        if(node.tag!bool)
            return;
        node.tag = true;
        e.cancel = true;
        auto path = "/master" ~ buildPath(node).chompPrefix("/root") ~ "/";
        auto task = new ExpandTask(node, path);
        task.start();
    }

    string buildPath(TreeNode node)
    {
        auto res = "";
        if(node.parent !is null)
            res ~= buildPath(node.parent);
        return res ~ "/" ~ node.text;
    }

    void logInfo(string message)
    {
        _logText.text = _logText.text ~ message;
    }
}

XlEntry[] getDir(string path)
{
    XlEntry[] files;
    auto file = path ~ "*";
    afs_finddata fd;
    auto first = FindFirst(cast(const (char)*)file.toStringz(), &fd);
    if(first != -1)
    {
        do
        {
            auto name = to!string(GetFileName(&fd));
            auto isDir = isDirectory(path ~ name);
            files ~= XlEntry(name, isDir);
        } while (FindNext(first, &fd) != -1);
    }
    FindClose(first);
    bool myComp(XlEntry a, XlEntry b) @safe pure nothrow { return a.isDir == b.isDir ? a.name < b.name : !b.isDir; }
    sort!(myComp)(files);
    return files;
}

bool isDirectory(string path)
{
    if(IsFileExist(cast(const (char)*)path.toStringz()))
        return false;
    afs_finddata fd;
    int first = FindFirst(cast(const (char)*)path.toStringz(), &fd);
    bool flag = first != -1;
    FindClose(first);
    return flag;
}

void fillNode(XlEntry[] entries, TreeNode parent)
{
    foreach(entry; entries)
    {
        auto node = parent.addNode(entry.name);
        node.tag = false;
        if(entry.isDir)
            node.addNode("(пусто)");
    }
}

bool contains(TreeNode node, string name)
{
    foreach(entry; node.nodes)
        if(entry.text == name)
            return true;
    return false;
}

/*extern (C++) void log(const (char)* message, ...)
{
    mainForm.logInfo(to!string(message));
}*/

MainForm mainForm;

int main()
{
    mainForm = new MainForm();
    mainForm.init();
    return Application.run(mainForm);
}


