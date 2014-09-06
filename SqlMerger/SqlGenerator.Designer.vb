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
        Me.GroupBox1 = New System.Windows.Forms.GroupBox()
        Me.GroupBox2 = New System.Windows.Forms.GroupBox()
        Me.btnClear = New System.Windows.Forms.Button()
        Me.btnCreate = New System.Windows.Forms.Button()
        Me.fileList = New System.Windows.Forms.ListBox()
        Me.txtSqlView = New System.Windows.Forms.TextBox()
        Me.Label1 = New System.Windows.Forms.Label()
        Me.GroupBox1.SuspendLayout()
        Me.GroupBox2.SuspendLayout()
        Me.SuspendLayout()
        '
        'GroupBox1
        '
        Me.GroupBox1.Controls.Add(Me.Label1)
        Me.GroupBox1.Controls.Add(Me.txtSqlView)
        Me.GroupBox1.Controls.Add(Me.fileList)
        Me.GroupBox1.Location = New System.Drawing.Point(8, 77)
        Me.GroupBox1.Name = "GroupBox1"
        Me.GroupBox1.Size = New System.Drawing.Size(456, 277)
        Me.GroupBox1.TabIndex = 0
        Me.GroupBox1.TabStop = False
        Me.GroupBox1.Text = "列表区"
        '
        'GroupBox2
        '
        Me.GroupBox2.Controls.Add(Me.btnClear)
        Me.GroupBox2.Controls.Add(Me.btnCreate)
        Me.GroupBox2.Location = New System.Drawing.Point(8, 7)
        Me.GroupBox2.Name = "GroupBox2"
        Me.GroupBox2.Size = New System.Drawing.Size(455, 64)
        Me.GroupBox2.TabIndex = 1
        Me.GroupBox2.TabStop = False
        Me.GroupBox2.Text = "合并控制台"
        '
        'btnClear
        '
        Me.btnClear.Location = New System.Drawing.Point(109, 21)
        Me.btnClear.Name = "btnClear"
        Me.btnClear.Size = New System.Drawing.Size(85, 27)
        Me.btnClear.TabIndex = 1
        Me.btnClear.Text = "清除列表"
        Me.btnClear.UseVisualStyleBackColor = True
        '
        'btnCreate
        '
        Me.btnCreate.Location = New System.Drawing.Point(12, 21)
        Me.btnCreate.Name = "btnCreate"
        Me.btnCreate.Size = New System.Drawing.Size(86, 28)
        Me.btnCreate.TabIndex = 0
        Me.btnCreate.Text = "开始合并"
        Me.btnCreate.UseVisualStyleBackColor = True
        '
        'fileList
        '
        Me.fileList.FormattingEnabled = True
        Me.fileList.ItemHeight = 12
        Me.fileList.Location = New System.Drawing.Point(12, 20)
        Me.fileList.Name = "fileList"
        Me.fileList.Size = New System.Drawing.Size(182, 244)
        Me.fileList.TabIndex = 0
        '
        'txtSqlView
        '
        Me.txtSqlView.Location = New System.Drawing.Point(203, 35)
        Me.txtSqlView.Multiline = True
        Me.txtSqlView.Name = "txtSqlView"
        Me.txtSqlView.ScrollBars = System.Windows.Forms.ScrollBars.Vertical
        Me.txtSqlView.Size = New System.Drawing.Size(240, 228)
        Me.txtSqlView.TabIndex = 1
        '
        'Label1
        '
        Me.Label1.AutoSize = True
        Me.Label1.Location = New System.Drawing.Point(201, 20)
        Me.Label1.Name = "Label1"
        Me.Label1.Size = New System.Drawing.Size(53, 12)
        Me.Label1.TabIndex = 2
        Me.Label1.Text = "文件预览"
        '
        'SqlGenerator
        '
        Me.AutoScaleDimensions = New System.Drawing.SizeF(6.0!, 12.0!)
        Me.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font
        Me.ClientSize = New System.Drawing.Size(470, 361)
        Me.Controls.Add(Me.GroupBox2)
        Me.Controls.Add(Me.GroupBox1)
        Me.Name = "SqlGenerator"
        Me.Text = "SQL合并工具"
        Me.GroupBox1.ResumeLayout(False)
        Me.GroupBox1.PerformLayout()
        Me.GroupBox2.ResumeLayout(False)
        Me.ResumeLayout(False)

    End Sub
    Friend WithEvents GroupBox1 As System.Windows.Forms.GroupBox
    Friend WithEvents GroupBox2 As System.Windows.Forms.GroupBox
    Friend WithEvents btnClear As System.Windows.Forms.Button
    Friend WithEvents btnCreate As System.Windows.Forms.Button
    Friend WithEvents Label1 As System.Windows.Forms.Label
    Friend WithEvents txtSqlView As System.Windows.Forms.TextBox
    Friend WithEvents fileList As System.Windows.Forms.ListBox

End Class
