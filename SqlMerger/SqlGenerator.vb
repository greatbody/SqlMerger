Imports System.IO

Public Class SqlGenerator
    Private _listBinder As ListBinder
    Private _remindNotice As NoticeBinder
    '【主界面】*********************************************************
    '【主界面】-【启动】
    Private Sub SqlGenerator_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        Me.Show()
        Dim _dSize As System.Drawing.Size
        _dSize.Height = 300
        _dSize.Width = 400
        Me.MinimumSize = _dSize
        _dSize.Height = 500
        _dSize.Width = 900
        Me.MaximumSize = _dSize
        _listBinder = New ListBinder(fileList)
        '添加提示信息

        Dim noticeBox As New ToolTip
        noticeBox.InitialDelay = 100
        noticeBox.AutoPopDelay = 5000
        noticeBox.ToolTipTitle = "[操作提示]"
        noticeBox.SetToolTip(fileList, "D:删除当前项" & vbCrLf & "↑:上移选中项" & vbCrLf & "↓:下移选中项")

        _remindNotice = New NoticeBinder(fileList)
        _remindNotice.Text = "拖动文件到此"
        _remindNotice.Adjust()
    End Sub
    '【主界面】-【改变尺寸】
    Private Sub SqlGenerator_Resize(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Resize
        grpEdit.Height = Me.ClientSize.Height - grpEdit.Top - 8 'done
        grpEdit.Width = Me.ClientSize.Width - grpEdit.Left - 4 'done
        Application.DoEvents()
        'fileList下边缘与窗体边缘对齐[height]
        fileList.Height = grpEdit.ClientSize.Height - fileList.Top - 4
        Application.DoEvents()
        'txtSqlView下边框，右边框[height,width]
        txtSqlView.Width = grpEdit.ClientSize.Width - txtSqlView.Left - 4
        Application.DoEvents()
        txtSqlView.Height = grpEdit.ClientSize.Height - txtSqlView.Top - 4
        Application.DoEvents()
    End Sub
    '【按钮事件处理】*********************************************************
    ''' <summary>
    ''' 合并SQL【合并SQL】
    ''' </summary>
    ''' <param name="sender"></param>
    ''' <param name="e"></param>
    ''' <remarks></remarks>
    Private Sub btnCreate_Click(ByVal sender As System.Object, ByVal e As System.EventArgs) Handles btnCreate.Click
        Dim _destPath As String = txtDestPath.Text
        Dim _tmpSqlCode As String = ""

        If String.IsNullOrEmpty(_destPath) Then
            _destPath = Application.StartupPath & "\" & Format(Now, "yyyy-MM-dd") & "merged.sql"
        End If

        If IO.File.Exists(_destPath) Then
            If MsgBox(String.Format("文件：{1}{0}已存在，是否覆盖？", vbCrLf, _destPath), MsgBoxStyle.OkCancel, "文件已存在") <> MsgBoxResult.Ok Then
                Exit Sub
            End If
        End If

        _tmpSqlCode = _listBinder.MergeFile(_destPath, chkAutoGo.Checked)
        txtSqlView.Text = _tmpSqlCode
    End Sub
    ''' <summary>
    ''' 清空列表【清空列表】
    ''' </summary>
    ''' <param name="sender"></param>
    ''' <param name="e"></param>
    ''' <remarks></remarks>
    Private Sub btnClear_Click(ByVal sender As System.Object, ByVal e As System.EventArgs) Handles btnClear.Click
        _fileList.Items.Clear()
    End Sub
    ''' <summary>
    ''' 复制到剪贴板【复制到剪贴板】
    ''' </summary>
    ''' <param name="sender"></param>
    ''' <param name="e"></param>
    ''' <remarks></remarks>
    Private Sub btnCopy_Click(ByVal sender As System.Object, ByVal e As System.EventArgs) Handles btnCopy.Click
        Dim _tmpText As String = txtSqlView.Text
        Clipboard.Clear()
        Clipboard.SetText(_tmpText)
    End Sub
    ''' <summary>
    ''' 选择导出路径【--】
    ''' </summary>
    ''' <param name="sender"></param>
    ''' <param name="e"></param>
    ''' <remarks></remarks>
    Private Sub btnSelFile_Click(ByVal sender As System.Object, ByVal e As System.EventArgs) Handles btnSelFile.Click
        txtDestPath.Text = SelectFiles("请选择生成文件的存储路径", "sql")
    End Sub
    '【文件列表控制】*********************************************************
    '【拖动】
    '【拖动】-【进入】
    Private Sub fileList_DragEnter(ByVal sender As Object, ByVal e As System.Windows.Forms.DragEventArgs) Handles fileList.DragEnter
        _remindNotice.Hide()
        e.Effect = DragDropEffects.All
    End Sub
    '【拖动】-【离开】
    Private Sub fileList_DragLeave(ByVal sender As Object, ByVal e As System.EventArgs) Handles fileList.DragLeave
        If fileList.Items.Count = 0 Then
            _remindNotice.Show()
        End If
    End Sub
    '【拖动】-【投递】
    Private Sub fileList_DragDrop(ByVal sender As System.Object, ByVal e As System.Windows.Forms.DragEventArgs) Handles fileList.DragDrop
        Dim _fileCollect() As String
        _fileCollect = e.Data.GetData(DataFormats.FileDrop)
        If _fileCollect.Length > 0 Then
            For Each _filePath As String In _fileCollect
                _listBinder.AddSqlFile(_filePath)
            Next
            _listBinder.Refresh()
        Else
            If fileList.Items.Count = 0 Then
                _remindNotice.Show()
            End If
        End If
    End Sub
    '【按键控制】*********************************************************
    Private Sub fileList_KeyDown(ByVal sender As Object, ByVal e As System.Windows.Forms.KeyEventArgs) Handles fileList.KeyDown
        If fileList.Items.Count > 0 Then
            If (e.KeyCode And Keys.Up) = Keys.Up Then
                _listBinder.MoveUp()
                Console.WriteLine("up")
                e.SuppressKeyPress = True
            End If
            If (e.KeyCode And Keys.Down) = Keys.Down Then
                _listBinder.MoveDown()
                Console.WriteLine("down")
                e.SuppressKeyPress = True
            End If
            If (e.KeyCode And Keys.D) = Keys.D OrElse (e.KeyCode And Keys.Delete) = Keys.Delete Then
                _listBinder.RemoveSelected()
                e.SuppressKeyPress = True
            End If
            If fileList.Items.Count = 0 Then
                _remindNotice.Show()
            End If
        End If
    End Sub
    '【公共函数】*********************************************************
    Public Shared Function SelectFiles(ByVal Describe As String, Optional ByVal DefaultExt As String = "") As String
        Dim nOpen As New System.Windows.Forms.SaveFileDialog
        '不检查文件是否存在
        nOpen.CheckFileExists = False
        '检查路径是否存在，并提示
        nOpen.CheckPathExists = True
        '设置文件选择对话框的标题
        nOpen.Title = Describe
        '如果指定不存在的文件，系统提示是否创建
        nOpen.CreatePrompt = False
        nOpen.DefaultExt = DefaultExt
        nOpen.Filter = "All Files(*.*)|*.*"

        Dim diaResult As DialogResult = nOpen.ShowDialog()
        If diaResult = DialogResult.OK Then
            Return nOpen.FileName
        Else
            Return Nothing
        End If
    End Function
End Class
