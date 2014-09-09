Public Class NoticeBinder
    Private _lblText As Label
    Private WithEvents _bindContext As Control
    Private _isBanded As Boolean = False
    Sub New()
        _lblText = New Label()
    End Sub

    Sub New(ByRef BindControl As Control)
        _lblText = New Label()
        _lblText.AutoSize = True
        _lblText.BackColor = Color.Transparent
        Bind(BindControl)
    End Sub

    Public Sub Bind(ByRef bindControl As Control)
        _bindContext = bindControl
        If _isBanded = False Then
            _bindContext.Controls.Add(_lblText)
        End If
    End Sub


    Private showText As String
    Public Property Text() As String
        Get
            Return showText
        End Get
        Set(ByVal value As String)
            showText = value
            _lblText.Text = showText
        End Set
    End Property

    Public Sub OnResize() Handles _bindContext.Resize
        _lblText.Left = (_bindContext.Width - _lblText.Width) / 2
    End Sub

    Public Sub Adjust()
        _lblText.Left = (_bindContext.ClientSize.Width - _lblText.Width) / 2
        _lblText.Top = (_bindContext.ClientSize.Height - _lblText.Height) / 2
    End Sub

    Public Sub Hide()
        _lblText.Visible = False
    End Sub

    public Sub Show()
        _lblText.Visible = True
    End Sub
End Class
