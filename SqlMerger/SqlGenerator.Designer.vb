<Global.Microsoft.VisualBasic.CompilerServices.DesignerGenerated()> _
Partial Class SqlGenerator
    Inherits System.Windows.Forms.Form

    'Form 重写 Dispose，以清理组件列表。
    <System.Diagnostics.DebuggerNonUserCode()> _
    Protected Overrides Sub Dispose(ByVal disposing As Boolean)
        Try
            If disposing AndAlso components IsNot Nothing Then
                components.Dispose()
            End If
        Finally
            MyBase.Dispose(disposing)
        End Try
    End Sub

    'Windows 窗体设计器所必需的
    Private components As System.ComponentModel.IContainer

    '注意: 以下过程是 Windows 窗体设计器所必需的
    '可以使用 Windows 窗体设计器修改它。
    '不要使用代码编辑器修改它。
    <System.Diagnostics.DebuggerStepThrough()> _
    Private Sub InitializeComponent()
        Dim resources As System.ComponentModel.ComponentResourceManager = New System.ComponentModel.ComponentResourceManager(GetType(SqlGenerator))
        Me.grpEdit = New System.Windows.Forms.GroupBox()
        Me.chkAutoGo = New System.Windows.Forms.CheckBox()
        Me.Label1 = New System.Windows.Forms.Label()
        Me.txtSqlView = New System.Windows.Forms.TextBox()
        Me.fileList = New System.Windows.Forms.ListBox()
        Me.grpControl = New System.Windows.Forms.GroupBox()
        Me.btnSelFile = New System.Windows.Forms.Button()
        Me.Label2 = New System.Windows.Forms.Label()
        Me.txtDestPath = New System.Windows.Forms.TextBox()
        Me.btnCopy = New System.Windows.Forms.Button()
        Me.btnClear = New System.Windows.Forms.Button()
        Me.btnCreate = New System.Windows.Forms.Button()
        Me.grpEdit.SuspendLayout()
        Me.grpControl.SuspendLayout()
        Me.SuspendLayout()
        '
        'grpEdit
        '
        Me.grpEdit.Controls.Add(Me.chkAutoGo)
        Me.grpEdit.Controls.Add(Me.Label1)
        Me.grpEdit.Controls.Add(Me.txtSqlView)
        Me.grpEdit.Controls.Add(Me.fileList)
        Me.grpEdit.Location = New System.Drawing.Point(0, 70)
        Me.grpEdit.Name = "grpEdit"
        Me.grpEdit.Size = New System.Drawing.Size(813, 377)
        Me.grpEdit.TabIndex = 0
        Me.grpEdit.TabStop = False
        Me.grpEdit.Text = "列表区"
        '
        'chkAutoGo
        '
        Me.chkAutoGo.AutoSize = True
        Me.chkAutoGo.Location = New System.Drawing.Point(256, 19)
        Me.chkAutoGo.Name = "chkAutoGo"
        Me.chkAutoGo.Size = New System.Drawing.Size(84, 16)
        Me.chkAutoGo.TabIndex = 3
        Me.chkAutoGo.Text = "自动添加Go"
        Me.chkAutoGo.UseVisualStyleBackColor = True
        '
        'Label1
        '
        Me.Label1.AutoSize = True
        Me.Label1.Location = New System.Drawing.Point(191, 17)
        Me.Label1.Name = "Label1"
        Me.Label1.Size = New System.Drawing.Size(53, 12)
        Me.Label1.TabIndex = 2
        Me.Label1.Text = "文件预览"
        '
        'txtSqlView
        '
        Me.txtSqlView.Location = New System.Drawing.Point(193, 43)
        Me.txtSqlView.Multiline = True
        Me.txtSqlView.Name = "txtSqlView"
        Me.txtSqlView.ScrollBars = System.Windows.Forms.ScrollBars.Vertical
        Me.txtSqlView.Size = New System.Drawing.Size(608, 322)
        Me.txtSqlView.TabIndex = 1
        '
        'fileList
        '
        Me.fileList.AllowDrop = True
        Me.fileList.FormattingEnabled = True
        Me.fileList.ItemHeight = 12
        Me.fileList.Location = New System.Drawing.Point(6, 17)
        Me.fileList.Name = "fileList"
        Me.fileList.Size = New System.Drawing.Size(179, 352)
        Me.fileList.TabIndex = 0
        '
        'grpControl
        '
        Me.grpControl.Controls.Add(Me.btnSelFile)
        Me.grpControl.Controls.Add(Me.Label2)
        Me.grpControl.Controls.Add(Me.txtDestPath)
        Me.grpControl.Controls.Add(Me.btnCopy)
        Me.grpControl.Controls.Add(Me.btnClear)
        Me.grpControl.Controls.Add(Me.btnCreate)
        Me.grpControl.Location = New System.Drawing.Point(6, 0)
        Me.grpControl.Name = "grpControl"
        Me.grpControl.Size = New System.Drawing.Size(795, 64)
        Me.grpControl.TabIndex = 1
        Me.grpControl.TabStop = False
        Me.grpControl.Text = "合并控制台"
        '
        'btnSelFile
        '
        Me.btnSelFile.FlatStyle = System.Windows.Forms.FlatStyle.Flat
        Me.btnSelFile.Location = New System.Drawing.Point(748, 25)
        Me.btnSelFile.Name = "btnSelFile"
        Me.btnSelFile.Size = New System.Drawing.Size(36, 21)
        Me.btnSelFile.TabIndex = 5
        Me.btnSelFile.Text = "--"
        Me.btnSelFile.UseVisualStyleBackColor = True
        '
        'Label2
        '
        Me.Label2.AutoSize = True
        Me.Label2.Location = New System.Drawing.Point(263, 31)
        Me.Label2.Name = "Label2"
        Me.Label2.Size = New System.Drawing.Size(41, 12)
        Me.Label2.TabIndex = 4
        Me.Label2.Text = "合并到"
        '
        'txtDestPath
        '
        Me.txtDestPath.Location = New System.Drawing.Point(310, 26)
        Me.txtDestPath.Name = "txtDestPath"
        Me.txtDestPath.Size = New System.Drawing.Size(431, 21)
        Me.txtDestPath.TabIndex = 3
        '
        'btnCopy
        '
        Me.btnCopy.Location = New System.Drawing.Point(158, 22)
        Me.btnCopy.Name = "btnCopy"
        Me.btnCopy.Size = New System.Drawing.Size(93, 27)
        Me.btnCopy.TabIndex = 2
        Me.btnCopy.Text = "复制到剪贴板"
        Me.btnCopy.UseVisualStyleBackColor = True
        '
        'btnClear
        '
        Me.btnClear.Location = New System.Drawing.Point(82, 21)
        Me.btnClear.Name = "btnClear"
        Me.btnClear.Size = New System.Drawing.Size(70, 28)
        Me.btnClear.TabIndex = 1
        Me.btnClear.Text = "清空列表"
        Me.btnClear.UseVisualStyleBackColor = True
        '
        'btnCreate
        '
        Me.btnCreate.Location = New System.Drawing.Point(12, 21)
        Me.btnCreate.Name = "btnCreate"
        Me.btnCreate.Size = New System.Drawing.Size(64, 28)
        Me.btnCreate.TabIndex = 0
        Me.btnCreate.Text = "合并SQL"
        Me.btnCreate.UseVisualStyleBackColor = True
        '
        'SqlGenerator
        '
        Me.AutoScaleDimensions = New System.Drawing.SizeF(6.0!, 12.0!)
        Me.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font
        Me.AutoSizeMode = System.Windows.Forms.AutoSizeMode.GrowAndShrink
        Me.ClientSize = New System.Drawing.Size(813, 447)
        Me.Controls.Add(Me.grpControl)
        Me.Controls.Add(Me.grpEdit)
        Me.Icon = CType(resources.GetObject("$this.Icon"), System.Drawing.Icon)
        Me.MaximizeBox = False
        Me.Name = "SqlGenerator"
        Me.Text = "SQL合并工具"
        Me.TopMost = True
        Me.grpEdit.ResumeLayout(False)
        Me.grpEdit.PerformLayout()
        Me.grpControl.ResumeLayout(False)
        Me.grpControl.PerformLayout()
        Me.ResumeLayout(False)

    End Sub
    Friend WithEvents grpEdit As System.Windows.Forms.GroupBox
    Friend WithEvents grpControl As System.Windows.Forms.GroupBox
    Friend WithEvents btnClear As System.Windows.Forms.Button
    Friend WithEvents btnCreate As System.Windows.Forms.Button
    Friend WithEvents Label1 As System.Windows.Forms.Label
    Friend WithEvents txtSqlView As System.Windows.Forms.TextBox
    Friend WithEvents fileList As System.Windows.Forms.ListBox
    Friend WithEvents btnCopy As System.Windows.Forms.Button
    Friend WithEvents txtDestPath As System.Windows.Forms.TextBox
    Friend WithEvents btnSelFile As System.Windows.Forms.Button
    Friend WithEvents Label2 As System.Windows.Forms.Label
    Friend WithEvents chkAutoGo As System.Windows.Forms.CheckBox

End Class
