Imports System.IO

Public Class SqlGenerator
    Private _listBinder As ListBinder

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
    End Sub

    Private Sub fileList_DragEnter(ByVal sender As Object, ByVal e As System.Windows.Forms.DragEventArgs) Handles fileList.DragEnter
        e.Effect = DragDropEffects.All
    End Sub


    Private Sub fileList_KeyDown(ByVal sender As Object, ByVal e As System.Windows.Forms.KeyEventArgs) Handles fileList.KeyDown
        If (e.KeyCode And Keys.Up) = Keys.Up Then
            _listBinder.MoveUp()
            Console.WriteLine("up")
        End If
        If (e.KeyCode And Keys.Down) = Keys.Down Then
            _listBinder.MoveDown()
            Console.WriteLine("down")
        End If
        e.SuppressKeyPress = True
        txtSqlView.Text = _listBinder.ViewData()
    End Sub

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

    Private Sub fileList_DragDrop(ByVal sender As System.Object, ByVal e As System.Windows.Forms.DragEventArgs) Handles fileList.DragDrop
        Dim _fileCollect() As String
        _fileCollect = e.Data.GetData(DataFormats.FileDrop)
        If _fileCollect.Length > 0 Then
            For Each _filePath As String In _fileCollect
                _listBinder.AddSqlFile(_filePath)
            Next
            _listBinder.Refresh()
        End If
    End Sub

    Private Sub btnCreate_Click(ByVal sender As System.Object, ByVal e As System.EventArgs) Handles btnCreate.Click
        txtSqlView.Text = _listBinder.MergeFile("E:\trys.txt")
    End Sub

    Private Sub btnClear_Click(ByVal sender As System.Object, ByVal e As System.EventArgs) Handles btnClear.Click
        _fileList.Items.Clear()
    End Sub

    Private Sub btnCopy_Click(ByVal sender As System.Object, ByVal e As System.EventArgs) Handles btnCopy.Click
        Dim _tmpText As String = txtSqlView.Text
        Clipboard.Clear()
        Clipboard.SetText(_tmpText)
    End Sub
End Class
