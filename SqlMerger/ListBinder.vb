Imports System.IO
Imports SunSoftUtility
Imports SunSoftUtility.TextProcessing
Imports System.Text

Public Class ListBinder
    Private _lstSqlFiles As ListBox
    Private _dicList As Dictionary(Of String, _FileData)
    Private _indexDic As New Dictionary(Of Integer, String)

    Private Structure _FileData
        Dim FilePath As String
        Dim OrderSequency As Integer
    End Structure
    Public Enum EventResult
        Success = 1
        IsDirectory = 2
        FileNotFound = 4
        DuplicateName = 8
    End Enum

    Sub New()
        '初始化变量
        _dicList = New Dictionary(Of String, _FileData)()
    End Sub

    Sub New(ByRef TheListBox As ListBox)
        '初始化绑定对象
        _lstSqlFiles = TheListBox
        '初始化变量
        _dicList = New Dictionary(Of String, _FileData)()
    End Sub

    Private Sub AddItem(ByVal key As String, ByVal value As _FileData)
        ValidVaribles()
        _dicList.Add(key, value)
    End Sub

    Public Function AddSqlFile(ByVal FilePath As String) As EventResult
        Dim FileName As String = ""
        If IO.File.Exists(FilePath) Then
            '路径存在，开始解析路径
            If IO.File.GetAttributes(FilePath) And FileAttributes.Directory Then
                '路径指示的为文件夹
                Return EventResult.IsDirectory
            End If
            '路径指向一个存在的文件
            FileName = Replace(FilePath, "/", "\")
            FileName = Mid(FileName, InStrRev(FileName, "\") + 1, FileName.Length - InStrRev(FileName, "\"))
            Dim _tfileData As _FileData
            _tfileData.FilePath = FilePath
            _tfileData.OrderSequency = _dicList.Count + 1
            If _dicList.ContainsKey(FileName) = True Then
                '出现重复的文件名
                Return EventResult.DuplicateName
            End If
            _dicList.Add(FileName, _tfileData)
            Return EventResult.Success
            '开始获取文件路径
        Else
            '文件不存在，添加失误
            Return EventResult.FileNotFound
        End If
    End Function

    Public Function ExChange(ByVal indexA As Integer, ByVal indexB As Integer) As Boolean
        ValidVaribles()
        If indexA < 1 OrElse indexB < 1 OrElse indexA > _dicList.Count OrElse indexB > _dicList.Count Then
            Throw New Exception("请检查代码，需要交换的两个对象序号不存在")
        End If
        Dim KeyA As String = ""
        Dim KeyB As String = ""
        Dim outCount As Integer = 0
        For Each fileData As KeyValuePair(Of String, _FileData) In _dicList
            If fileData.Value.OrderSequency = indexA Then
                KeyA = fileData.Key
                outCount += 1
            End If
            If fileData.Value.OrderSequency = indexB Then
                KeyB = fileData.Key
                outCount += 1
            End If
            If outCount >= 2 Then
                Exit For
            End If
        Next
        If outCount < 2 Then
            Throw New Exception("请检查代码，需要交换的两个对象序号至少有一个不存在")
        End If
        Dim tmpA As _FileData = _dicList.Item(KeyA)
        tmpA.OrderSequency = indexB
        Dim tmpB As _FileData = _dicList.Item(KeyB)
        tmpB.OrderSequency = indexA
        _dicList.Item(KeyA) = tmpA
        _dicList.Item(KeyB) = tmpB
        Return True
    End Function

    Public Sub Refresh()
        Refresh(0)
    End Sub

    Public Sub FillSeqDictionary()
        _indexDic.Clear()
        If _dicList.Count > 0 Then
            For Each fileData As KeyValuePair(Of String, _FileData) In _dicList
                _indexDic.Add(fileData.Value.OrderSequency, fileData.Key)
            Next
        End If
    End Sub

    Public Sub Refresh(ByVal DefaultSelIndex As Integer)
        _lstSqlFiles.Enabled = False
        _indexDic.Clear()
        _lstSqlFiles.Items.Clear()

        If _dicList.Count > 0 Then

            For Each fileData As KeyValuePair(Of String, _FileData) In _dicList
                _indexDic.Add(fileData.Value.OrderSequency, fileData.Key)
            Next

            For i As Integer = 1 To _indexDic.Count
                _lstSqlFiles.Items.Add(_indexDic.Item(i))
            Next
            Application.DoEvents()
            If DefaultSelIndex < _lstSqlFiles.Items.Count AndAlso DefaultSelIndex >= 0 Then
                _lstSqlFiles.Enabled = True
                _lstSqlFiles.Focus()
                _lstSqlFiles.SelectedIndex = DefaultSelIndex
                Exit Sub
            End If
        End If
        _lstSqlFiles.Enabled = True
        _lstSqlFiles.Focus()
    End Sub

    Public Sub MoveUp()
        Dim _selectedIndex As Integer = 0
        ValidVaribles()

        If _lstSqlFiles.Items.Count > 0 Then
            '仅当有数据时执行代码
            _selectedIndex = _lstSqlFiles.SelectedIndex
            If _selectedIndex > 0 Then
                '只有当被选中项不是第一个的时候，才能往上移动
                ExChange(_selectedIndex + 1, _selectedIndex)
                Refresh(_selectedIndex - 1)
            End If
        End If

    End Sub

    Public Sub MoveDown()
        Dim _selectedIndex As Integer = 0
        ValidVaribles()

        If _lstSqlFiles.Items.Count > 0 Then
            '仅当有数据时执行代码
            _selectedIndex = _lstSqlFiles.SelectedIndex
            If _selectedIndex < _lstSqlFiles.Items.Count - 1 Then
                '只有当被选中项不是最后一个的时候，才能往下移动
                ExChange(_selectedIndex + 1, _selectedIndex + 2)
                Refresh(_selectedIndex + 1)
            End If
        End If

    End Sub

    Private Sub ValidVaribles()
        If _dicList Is Nothing Then
            Throw New Exception("_dicList并未实例化，请检查代码！")
        End If
        If _lstSqlFiles Is Nothing Then
            Throw New Exception("_lstSqlFiles未初始化！")
        End If
    End Sub

    Private Function ViewData() As String
        If _dicList.Count > 0 Then
            Dim _DataStr As New StringBuilder
            Dim _tmpKey As String = ""
            _DataStr.AppendLine(String.Format("序号{0}文件名{0}{0}路径", vbTab))
            For i As Integer = 1 To _indexDic.Count
                _tmpKey = _indexDic.Item(i)
                _DataStr.AppendLine(String.Format("{1}{0}{2}{0}{0}{3}", vbTab, i, _tmpKey, _dicList.Item(_tmpKey).FilePath))
            Next
            Return _DataStr.ToString()
        End If
        Return ""
    End Function
    ''' <summary>
    ''' 将列表中的文件合并到一起，输出到指定路径
    ''' </summary>
    ''' <param name="DestPath">目标路径</param>
    ''' <remarks></remarks>
    Public Function MergeFile(ByVal DestPath As String) As String
        Return MergeFile(DestPath, False)
    End Function

    Public Function MergeFile(ByVal DestPath As String, ByVal AutoGo As Boolean) As String
        FillSeqDictionary()
        Dim _mergeBuilder As New StringBuilder
        Dim _mergeStr As String
        _mergeBuilder.AppendLine("--copy right sunsoft")
        _mergeBuilder.AppendLine(String.Format("--Created At :{0}", Format(Now, "yyyy-MM-dd hh:mm:ss")))
        _mergeBuilder.AppendLine(String.Format("--Created By :{0}", My.User.Name))
        For i As Integer = 1 To _indexDic.Count
            If AutoGo Then
                _mergeBuilder.AppendLine("Go")
            End If
            _mergeBuilder.AppendLine(ReadFile(_dicList.Item(_indexDic.Item(i)).FilePath))
            _mergeBuilder.AppendLine("")
        Next
        _mergeStr = _mergeBuilder.ToString()
        WriteToFile(DestPath, _mergeStr)
        Return _mergeStr
    End Function

    Private Sub RemoveAtIndex(ByVal itemIndex As Integer)
        FillSeqDictionary()
        Dim keyName As String
        Dim _tmpFileData As _FileData
        Dim _count As Integer = 1
        keyName = _indexDic.Item(itemIndex + 1)
        _dicList.Remove(keyName)
        '重新设置SeqID
        For i As Integer = 1 To _indexDic.Count

            If _dicList.ContainsKey(_indexDic.Item(i)) Then
                If _dicList.Item(_indexDic.Item(i)).OrderSequency <> _count Then
                    _tmpFileData = _dicList.Item(_indexDic.Item(i))
                    _tmpFileData.OrderSequency = _count
                    _dicList.Item(_indexDic.Item(i)) = _tmpFileData
                End If
                _count += 1
            End If
        Next
        If _lstSqlFiles.Items.Count - 1 > itemIndex Then
            Refresh(itemIndex)
        Else
            Refresh()
        End If
    End Sub

    Public Sub RemoveSelected()
        RemoveAtIndex(_lstSqlFiles.SelectedIndex)
    End Sub

    Public Function Item(ByVal Key As String) As String
        Return _dicList.Item(Key).FilePath
    End Function
End Class
