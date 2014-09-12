--copy right sunsoft
--Created At :2014-09-12 05:01:57
--Created By :MYSOFT\sunr01
--�����ж�һ������¥���Ƿ�δ����(�����Ǵ��ڵ��۷����е�¥��)
IF  EXISTS ( SELECT  *
                FROM    sysobjects
                WHERE   xtype = 'fn'
                        AND name = 'fn_IsWtsBld' ) 
    BEGIN
        DROP FUNCTION [dbo].[fn_IsWtsBld]
    END
go
CREATE FUNCTION [dbo].[fn_IsWtsBld]
    (
	@BldGUID  varchar(40)	--����¥��guid
    )
RETURNS int
AS 
	BEGIN
		
		DECLARE @r AS INT
		DECLARE @totaldj AS MONEY
		SET @r=0
		SET @totaldj=0
		--��ǰ����¥����Ӧ������¥����Ӧ�ĵ��ܼ�
		SELECT @totaldj=ISNULL(SUM(ISNULL(TotalDj,0)),0)
		FROM dbo.jd_GCBuilding gcb
		INNER JOIN dbo.p_Building pb ON pb.ParentCode + '.' + pb.BldCode = gcb.BldFullCode
		INNER JOIN dbo.p_Room room ON room.BldGUID=pb.BldGUID
		WHERE gcb.BldGUID=@BldGUID
		
		--�Ƿ�  ¥��δ����
		IF EXISTS(
			SELECT 1
			FROM dbo.jd_GCBuilding gcb
			LEFT JOIN dbo.p_Building pb ON pb.ParentCode + '.' + pb.BldCode = gcb.BldFullCode
			LEFT JOIN dbo.p_Room room ON room.BldGUID=pb.BldGUID
			WHERE gcb.BldGUID=@BldGUID
			AND (pb.BldGUID IS NULL	--δ������
				OR (pb.BldGUID IS NOT NULL AND NOT EXISTS(SELECT RoomGUID FROM dbo.p_Room WHERE BldGUID=pb.BldGUID)) --�����룬��δ��������
				OR (pb.BldGUID IS NOT NULL AND EXISTS(SELECT RoomGUID FROM dbo.p_Room WHERE BldGUID=pb.BldGUID) AND @totaldj=0)
				)
		)
		BEGIN
				set @r=1
		END

		RETURN @r
		
	END
 GO 


--��������˹���¥��������¥��
-------------------------
  
ALTER  FUNCTION [dbo].[fn_GetYtNameFromBld]
    (
      @BldGUID UNIQUEIDENTIFIER ,		--¥��GUID
      @BldType AS VARCHAR(20)		--¥������
    )
RETURNS VARCHAR(200)
AS
    BEGIN  
 --�ڹ���¥�����Ҹ�¥����ProductGUID���ڴӲ�Ʒ���ͱ�cb_HkbProductWork������BProductTypeName   
        DECLARE @r AS VARCHAR(200)  
        SET @r = ''  
        IF @BldType = 'gcbuilding'
            BEGIN
                SELECT  @r = ProductName
                FROM    cb_HkbProductWork
                WHERE   ProductGUID IN ( SELECT ProductGUID
                                         FROM   dbo.jd_GCBuilding
                                         WHERE  BldGUID = @BldGUID )  
            END
        ELSE
            BEGIN
                SELECT  @r = ProductName
                FROM    cb_HkbProductWork
                WHERE   ProductGUID IN ( SELECT ProductGUID
                                         FROM   dbo.p_Building
                                         WHERE  BldGUID = @BldGUID )  
            END

        IF ISNULL(@r,'') = ''
            BEGIN
                SET @r = '����'
            END
        RETURN @r  
   
    END  

GO






ALTER  FUNCTION [dbo].[fn_IsWTsBldAndNoBcPlan](
	@BldGUID  varchar(40),	--����¥��GUID
	@PlanGUID varchar(40)	--���۷���GUID
)
RETURNS int
AS
BEGIN
	
	DECLARE @r AS int
	SET @r=0
	--�Ƿ�  ¥��δ�����Ҳ��ڱ��α�����
	IF dbo.fn_IsWtsBld(@BldGUID)=1
	BEGIN
		if not exists(select 1
		from dbo.jd_GCBuilding gcb
		LEFT JOIN dbo.p_Building pb ON pb.ParentCode + '.' + pb.BldCode = gcb.BldFullCode
		LEFT JOIN p_Room room on room.BldGUID=pb.BldGUID
		LEFT JOIN dbo.s_DjTjResult rst ON rst.RoomGUID=room.RoomGUID AND rst.PlanGUID=@PlanGUID
		where rst.RoomGUID IS NOT NULL AND gcb.BldGUID=@BldGUID)
		BEGIN
			set @r=1
		END
	END
	

	
	RETURN @r
	
END

GO




IF  EXISTS ( SELECT  *
                FROM    sysobjects
                WHERE   xtype = 'fn'
                        AND name = 'fn_IsWTsBldAndNoBcPlan_Tjf' ) 
    BEGIN
        DROP FUNCTION [dbo].[fn_IsWTsBldAndNoBcPlan_Tjf]
    END
go

CREATE  FUNCTION [dbo].[fn_IsWTsBldAndNoBcPlan_Tjf](
	@BldGUID  varchar(40),	--����¥��GUID
	@PlanGUID varchar(40)	--���۷���GUID
)
RETURNS int
AS
BEGIN
	
	DECLARE @r AS int
	SET @r=0
	--�Ƿ�  ¥��δ�����Ҳ��ڱ��α�����
	IF dbo.fn_IsWtsBld(@BldGUID)=1
	BEGIN
		if not exists(select 1
		from dbo.jd_GCBuilding gcb
		LEFT JOIN dbo.p_Building pb ON pb.ParentCode + '.' + pb.BldCode = gcb.BldFullCode
		LEFT JOIN p_Room room on room.BldGUID=pb.BldGUID
		LEFT JOIN dbo.s_TjTjResult rst ON rst.RoomGUID=room.RoomGUID AND rst.TjPlanGUID=@PlanGUID
		where rst.RoomGUID IS NOT NULL AND gcb.BldGUID=@BldGUID)
		BEGIN
			set @r=1
		END
	END
	

	
	RETURN @r
	
END

GO




--�����ж�һ������¥���Ƿ�δ����(�����Ǵ��ڵ��۷����е�¥��)
IF  EXISTS ( SELECT  *
                FROM    sysobjects
                WHERE   xtype = 'fn'
                        AND name = 'fn_CalcBldValue' ) 
    BEGIN
        DROP FUNCTION [dbo].[fn_CalcBldValue]
    END
go
CREATE FUNCTION [dbo].[fn_CalcBldValue]
    (
	@BldGUID  varchar(40),		--����¥��guid
	@CalcType varchar(50),		--��������
	@PlanGUID UNIQUEIDENTIFIER	--���۷���GUID
    )
RETURNS DECIMAL(23,4)
AS 
	BEGIN
		--�������
		DECLARE @r AS DECIMAL(23,4)
		--
		IF @CalcType='bcbp_area_any' --������wts��������
			BEGIN
				SELECT @r=ISNULL(SUM(ISNULL(case when isnull(ScBldArea,0)=0 then isnull(YsBldArea,0) else isnull(ScBldArea,0) end,0)),0)
				FROM dbo.jd_GCBuilding gcb
				LEFT JOIN dbo.p_Building pb ON pb.ParentCode + '.' + pb.BldCode = gcb.BldFullCode
				LEFT join dbo.p_Room room ON room.BldGUID = pb.BldGUID
				INNER JOIN dbo.s_DjTjResult rst ON rst.RoomGUID=room.RoomGUID AND rst.PlanGUID=@PlanGUID
				WHERE gcb.BldGUID=@BldGUID
				RETURN @r
			END
		ELSE IF @CalcType='bcbp_hz_any'
			BEGIN
				SELECT @r=ISNULL(CASE WHEN ISNULL(SUM(ISNULL(room.BldArea,0)),0)=0 THEN 0 ELSE SUM(ISNULL(rst.TotalDj,0))/SUM(ISNULL(room.BldArea,0)) END,0)
				FROM dbo.jd_GCBuilding gcb
				LEFT JOIN dbo.p_Building pb ON pb.ParentCode + '.' + pb.BldCode = gcb.BldFullCode
				LEFT join dbo.p_Room room ON room.BldGUID = pb.BldGUID
				INNER JOIN dbo.s_DjTjResult rst ON rst.RoomGUID=room.RoomGUID AND rst.PlanGUID=@PlanGUID
				WHERE gcb.BldGUID=@BldGUID
				RETURN @r
			END
		--��ǰ¥����δ����
		IF dbo.fn_IsWtsBld(@BldGUID)=1
			BEGIN
				IF @CalcType='targetdtarea' OR @CalcType='tzqdt'
					BEGIN
						SELECT @r=ISNULL(SUM(ISNULL(gcb.KsArea,0)),0)
						FROM dbo.jd_GCBuilding gcb
						LEFT JOIN dbo.p_Building pb ON pb.ParentCode + '.' + pb.BldCode = gcb.BldFullCode
						LEFT JOIN dbo.p_Room room ON room.BldGUID=pb.BldGUID
						WHERE gcb.BldGUID=@BldGUID
					END
				ELSE IF @CalcType='ytys_area' OR @CalcType='ytws_area' OR @CalcType='ytys_hz' OR @CalcType='ytws_hz'
					BEGIN
						SET @r=0	--δ���۵�¥�������������ֶ�Ĭ��Ϊ0
					END
				ELSE IF @CalcType='targetdtarea_hz' OR @CalcType='tzqdt_hz' OR @CalcType='tzqdt_hz_special'
					BEGIN
						SELECT @r=ISNULL(SUM(ISNULL(gcb.YSMBTotle,0)),0)
						FROM dbo.jd_GCBuilding gcb
						LEFT JOIN dbo.p_Building pb ON pb.ParentCode + '.' + pb.BldCode = gcb.BldFullCode
						LEFT JOIN dbo.p_Room room ON room.BldGUID=pb.BldGUID
						WHERE gcb.BldGUID=@BldGUID						
					END
			END
		ELSE
			--��ǰ¥����������
			BEGIN
				IF @CalcType='targetdtarea'
					BEGIN
						SELECT @r=ISNULL(SUM(ISNULL(room.YsBldArea,0)),0)
						FROM dbo.jd_GCBuilding gcb
						LEFT JOIN dbo.p_Building pb ON pb.ParentCode + '.' + pb.BldCode = gcb.BldFullCode
						LEFT JOIN dbo.p_Room room ON room.BldGUID=pb.BldGUID
						WHERE gcb.BldGUID=@BldGUID
					END
				ELSE IF @CalcType='targetdtarea_hz'
					BEGIN
						SELECT @r=ISNULL(CASE WHEN ISNULL(SUM(ISNULL(room.YsBldArea,0)),0)=0 THEN 0 ELSE SUM(ISNULL(TotalDj,0))/SUM(ISNULL(room.YsBldArea,0)) END,0)
						FROM dbo.jd_GCBuilding gcb
						LEFT JOIN dbo.p_Building pb ON pb.ParentCode + '.' + pb.BldCode = gcb.BldFullCode
						LEFT JOIN dbo.p_Room room ON room.BldGUID=pb.BldGUID
						WHERE gcb.BldGUID=@BldGUID
					END
				ELSE IF @CalcType='tzqdt'
					BEGIN
						SELECT @r=ISNULL(SUM(ISNULL(case when isnull(ScBldArea,0)=0 then isnull(YsBldArea,0) else isnull(ScBldArea,0) end,0)),0)
						FROM dbo.jd_GCBuilding gcb
						LEFT JOIN dbo.p_Building pb ON pb.ParentCode + '.' + pb.BldCode = gcb.BldFullCode
						LEFT JOIN dbo.p_Room room ON room.BldGUID=pb.BldGUID
						WHERE gcb.BldGUID=@BldGUID
					END
				ELSE IF @CalcType='ytys_area'
					BEGIN
						SELECT @r=isnull(sum( case when isnull(ScBldArea,0)=0 then isnull(YsBldArea,0) else isnull(ScBldArea,0) end  ),0)
						FROM dbo.jd_GCBuilding gcb
						LEFT JOIN dbo.p_Building pb ON pb.ParentCode + '.' + pb.BldCode = gcb.BldFullCode
						LEFT JOIN dbo.p_Room room ON room.BldGUID=pb.BldGUID
						WHERE gcb.BldGUID=@BldGUID
						AND EXISTS(SELECT 1 FROM s_trade WHERE RoomGUID=room.RoomGUID AND TradeStatus='����')
						AND Status IN ('�Ϲ�','ǩԼ')
					END
				ELSE IF @CalcType='tzqdt_hz'
					BEGIN
						SET @r=0 --ScData��������ˣ������۲��ֵģ���������Ϊ0
					END
				ELSE IF @CalcType='tzqdt_hz_special'
					BEGIN
						SELECT @r=ISNULL(CASE WHEN ISNULL(SUM(ISNULL(room.ScBldArea,0)),0)=0 THEN SUM(ISNULL(TotalDj,0))/SUM(ISNULL(room.YsBldArea,0)) ELSE SUM(ISNULL(TotalDj,0))/SUM(ISNULL(room.ScBldArea,0)) END,0)
						FROM dbo.jd_GCBuilding gcb
						LEFT JOIN dbo.p_Building pb ON pb.ParentCode + '.' + pb.BldCode = gcb.BldFullCode
						LEFT JOIN dbo.p_Room room ON room.BldGUID=pb.BldGUID
						WHERE gcb.BldGUID=@BldGUID
					END
				ELSE IF @CalcType='ytws_area'
					BEGIN
						SELECT @r=isnull(sum( case when isnull(ScBldArea,0)=0 then isnull(YsBldArea,0) else isnull(ScBldArea,0) end  ),0)
						FROM dbo.jd_GCBuilding gcb
						LEFT JOIN dbo.p_Building pb ON pb.ParentCode + '.' + pb.BldCode = gcb.BldFullCode
						LEFT JOIN dbo.p_Room room ON room.BldGUID=pb.BldGUID
						WHERE gcb.BldGUID=@BldGUID
						AND EXISTS(SELECT 1 FROM s_trade WHERE RoomGUID=room.RoomGUID AND ISNULL(TradeStatus,'')<>'����')
						AND Status IN ('�Ϲ�','ǩԼ')
						AND room.RoomGUID not IN (SELECT RoomGUID FROM dbo.s_DjTjResult WHERE PlanGUID=@PlanGUID)
					END
				ELSE IF @CalcType='ytys_hz'
					BEGIN
						SELECT @r=isnull([dbo].[fn_BldInfoSum](pb.BldGUID,'YTYSHz'),0)
						FROM dbo.jd_GCBuilding gcb
						LEFT JOIN dbo.p_Building pb ON pb.ParentCode + '.' + pb.BldCode = gcb.BldFullCode
						LEFT JOIN dbo.p_Room room ON room.BldGUID=pb.BldGUID
						WHERE gcb.BldGUID=@BldGUID
					END
				ELSE IF @CalcType='ytws_hz'
					BEGIN
						SELECT @r=ISNULL(SUM(ISNULL(TotalDj,0))/SUM(ISNULL(BldArea,0)),0)
						FROM dbo.jd_GCBuilding gcb
						LEFT JOIN dbo.p_Building pb ON pb.ParentCode + '.' + pb.BldCode = gcb.BldFullCode
						LEFT JOIN dbo.p_Room room ON room.BldGUID=pb.BldGUID
						WHERE gcb.BldGUID=@BldGUID
						AND EXISTS(SELECT 1 FROM s_trade WHERE RoomGUID=room.RoomGUID AND ISNULL(TradeStatus,'')<>'����')
						AND Status IN ('�Ϲ�','ǩԼ')
						AND room.RoomGUID not IN (SELECT RoomGUID FROM dbo.s_DjTjResult WHERE PlanGUID=@PlanGUID)
					END
			END
		RETURN @r
		
	END
 GO 


--�����ж�һ������¥���Ƿ�δ����(�����Ǵ��ڵ��۷����е�¥��)
IF  EXISTS ( SELECT  *
                FROM    sysobjects
                WHERE   xtype = 'fn'
                        AND name = 'fn_CalcBldValue_Tjf' ) 
    BEGIN
        DROP FUNCTION [dbo].[fn_CalcBldValue_Tjf]
    END
go
CREATE FUNCTION [dbo].[fn_CalcBldValue_Tjf]
    (
	@BldGUID  varchar(40),		--����¥��guid
	@CalcType varchar(50),		--��������
	@PlanGUID UNIQUEIDENTIFIER	--���۷���GUID
    )
RETURNS DECIMAL(23,4)
AS 
	BEGIN
		--�������
		DECLARE @r AS DECIMAL(23,4)
		--
		IF @CalcType='bcbp_area_any' --������wts��������
			BEGIN
				SELECT @r=ISNULL(SUM(ISNULL(case when isnull(ScBldArea,0)=0 then isnull(YsBldArea,0) else isnull(ScBldArea,0) end,0)),0)
				FROM dbo.jd_GCBuilding gcb
				LEFT JOIN dbo.p_Building pb ON pb.ParentCode + '.' + pb.BldCode = gcb.BldFullCode
				LEFT join dbo.p_Room room ON room.BldGUID = pb.BldGUID
				INNER JOIN dbo.s_TjTjResult rst ON rst.RoomGUID=room.RoomGUID AND rst.TjPlanGUID=@PlanGUID
				WHERE gcb.BldGUID=@BldGUID
				RETURN @r
			END
		ELSE IF @CalcType='bcbp_hz_any'
			BEGIN
				SELECT @r=ISNULL(CASE WHEN ISNULL(SUM(ISNULL(room.BldArea,0)),0)=0 THEN 0 ELSE SUM(ISNULL(rst.TotalTj,0))/SUM(ISNULL(room.BldArea,0)) END,0)
				FROM dbo.jd_GCBuilding gcb
				LEFT JOIN dbo.p_Building pb ON pb.ParentCode + '.' + pb.BldCode = gcb.BldFullCode
				LEFT join dbo.p_Room room ON room.BldGUID = pb.BldGUID
				INNER JOIN dbo.s_TjTjResult rst ON rst.RoomGUID=room.RoomGUID AND rst.TjPlanGUID=@PlanGUID
				WHERE gcb.BldGUID=@BldGUID
				RETURN @r
			END
		--��ǰ¥����δ����
		IF dbo.fn_IsWtsBld(@BldGUID)=1
			BEGIN
				IF @CalcType='targetdtarea' OR @CalcType='tzqdt'
					BEGIN
						SELECT @r=ISNULL(SUM(ISNULL(gcb.KsArea,0)),0)
						FROM dbo.jd_GCBuilding gcb
						LEFT JOIN dbo.p_Building pb ON pb.ParentCode + '.' + pb.BldCode = gcb.BldFullCode
						LEFT JOIN dbo.p_Room room ON room.BldGUID=pb.BldGUID
						WHERE gcb.BldGUID=@BldGUID
					END
				ELSE IF @CalcType='ytys_area' OR @CalcType='ytws_area' OR @CalcType='ytys_hz' OR @CalcType='ytws_hz'
					BEGIN
						SET @r=0	--δ���۵�¥�������������ֶ�Ĭ��Ϊ0
					END
				ELSE IF @CalcType='targetdtarea_hz' OR @CalcType='tzqdt_hz' OR @CalcType='tzqdt_hz_special'
					BEGIN
						SELECT @r=ISNULL(SUM(ISNULL(gcb.YSMBTotle,0)),0)
						FROM dbo.jd_GCBuilding gcb
						LEFT JOIN dbo.p_Building pb ON pb.ParentCode + '.' + pb.BldCode = gcb.BldFullCode
						LEFT JOIN dbo.p_Room room ON room.BldGUID=pb.BldGUID
						WHERE gcb.BldGUID=@BldGUID						
					END
			END
		ELSE
			--��ǰ¥����������
			BEGIN
				IF @CalcType='targetdtarea'
					BEGIN
						SELECT @r=ISNULL(SUM(ISNULL(room.YsBldArea,0)),0)
						FROM dbo.jd_GCBuilding gcb
						LEFT JOIN dbo.p_Building pb ON pb.ParentCode + '.' + pb.BldCode = gcb.BldFullCode
						LEFT JOIN dbo.p_Room room ON room.BldGUID=pb.BldGUID
						WHERE gcb.BldGUID=@BldGUID
					END
				ELSE IF @CalcType='targetdtarea_hz'
					BEGIN
						SELECT @r=ISNULL(CASE WHEN ISNULL(SUM(ISNULL(room.YsBldArea,0)),0)=0 THEN 0 ELSE SUM(ISNULL(TotalDj,0))/SUM(ISNULL(room.YsBldArea,0)) END,0)
						FROM dbo.jd_GCBuilding gcb
						LEFT JOIN dbo.p_Building pb ON pb.ParentCode + '.' + pb.BldCode = gcb.BldFullCode
						LEFT JOIN dbo.p_Room room ON room.BldGUID=pb.BldGUID
						WHERE gcb.BldGUID=@BldGUID
					END
				ELSE IF @CalcType='tzqdt'
					BEGIN
						SELECT @r=ISNULL(SUM(ISNULL(case when isnull(ScBldArea,0)=0 then isnull(YsBldArea,0) else isnull(ScBldArea,0) end,0)),0)
						FROM dbo.jd_GCBuilding gcb
						LEFT JOIN dbo.p_Building pb ON pb.ParentCode + '.' + pb.BldCode = gcb.BldFullCode
						LEFT JOIN dbo.p_Room room ON room.BldGUID=pb.BldGUID
						WHERE gcb.BldGUID=@BldGUID
					END
				ELSE IF @CalcType='ytys_area'
					BEGIN
						SELECT @r=isnull(sum( case when isnull(ScBldArea,0)=0 then isnull(YsBldArea,0) else isnull(ScBldArea,0) end  ),0)
						FROM dbo.jd_GCBuilding gcb
						LEFT JOIN dbo.p_Building pb ON pb.ParentCode + '.' + pb.BldCode = gcb.BldFullCode
						LEFT JOIN dbo.p_Room room ON room.BldGUID=pb.BldGUID
						WHERE gcb.BldGUID=@BldGUID
						AND EXISTS(SELECT 1 FROM s_trade WHERE RoomGUID=room.RoomGUID AND TradeStatus='����')
						AND Status IN ('�Ϲ�','ǩԼ')
					END
				ELSE IF @CalcType='tzqdt_hz'
					BEGIN
						SET @r=0 --ScData��������ˣ������۲��ֵģ���������Ϊ0
					END
				ELSE IF @CalcType='tzqdt_hz_special'
					BEGIN
						SELECT @r=ISNULL(CASE WHEN ISNULL(SUM(ISNULL(room.ScBldArea,0)),0)=0 THEN SUM(ISNULL(TotalDj,0))/SUM(ISNULL(room.YsBldArea,0)) ELSE SUM(ISNULL(TotalDj,0))/SUM(ISNULL(room.ScBldArea,0)) END,0)
						FROM dbo.jd_GCBuilding gcb
						LEFT JOIN dbo.p_Building pb ON pb.ParentCode + '.' + pb.BldCode = gcb.BldFullCode
						LEFT JOIN dbo.p_Room room ON room.BldGUID=pb.BldGUID
						WHERE gcb.BldGUID=@BldGUID
					END
				ELSE IF @CalcType='ytws_area'
					BEGIN
						SELECT @r=isnull(sum( case when isnull(ScBldArea,0)=0 then isnull(YsBldArea,0) else isnull(ScBldArea,0) end  ),0)
						FROM dbo.jd_GCBuilding gcb
						LEFT JOIN dbo.p_Building pb ON pb.ParentCode + '.' + pb.BldCode = gcb.BldFullCode
						LEFT JOIN dbo.p_Room room ON room.BldGUID=pb.BldGUID
						WHERE gcb.BldGUID=@BldGUID
						AND EXISTS(SELECT 1 FROM s_trade WHERE RoomGUID=room.RoomGUID AND ISNULL(TradeStatus,'')<>'����')
						AND Status IN ('�Ϲ�','ǩԼ')
						AND room.RoomGUID not IN (SELECT RoomGUID FROM dbo.s_TjTjResult WHERE TjPlanGUID=@PlanGUID)
					END
				ELSE IF @CalcType='ytys_hz'
					BEGIN
						SELECT @r=isnull([dbo].[fn_BldInfoSum](pb.BldGUID,'YTYSHz'),0)
						FROM dbo.jd_GCBuilding gcb
						LEFT JOIN dbo.p_Building pb ON pb.ParentCode + '.' + pb.BldCode = gcb.BldFullCode
						LEFT JOIN dbo.p_Room room ON room.BldGUID=pb.BldGUID
						WHERE gcb.BldGUID=@BldGUID
					END
				ELSE IF @CalcType='ytws_hz'
					BEGIN
						SELECT @r=ISNULL(SUM(ISNULL(TotalDj,0))/SUM(ISNULL(BldArea,0)),0)
						FROM dbo.jd_GCBuilding gcb
						LEFT JOIN dbo.p_Building pb ON pb.ParentCode + '.' + pb.BldCode = gcb.BldFullCode
						LEFT JOIN dbo.p_Room room ON room.BldGUID=pb.BldGUID
						WHERE gcb.BldGUID=@BldGUID
						AND EXISTS(SELECT 1 FROM s_trade WHERE RoomGUID=room.RoomGUID AND ISNULL(TradeStatus,'')<>'����')
						AND Status IN ('�Ϲ�','ǩԼ')
						AND room.RoomGUID not IN (SELECT RoomGUID FROM dbo.s_TjTjResult WHERE TjPlanGUID=@PlanGUID)
					END
			END
		RETURN @r
		
	END
 GO 


IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].usp_jg_ScData') AND OBJECTPROPERTY(id, N'IsProcedure') = 1)
	DROP PROCEDURE [dbo].usp_jg_ScData
GO

CREATE PROCEDURE [dbo].[usp_jg_ScData]  
    @PlanGUID VARCHAR(40) 
AS   
BEGIN    

IF @PlanGUID='' 
BEGIN
	RETURN 
END

DECLARE @ProjGUID AS varchar(40)	--һ����ĿGUID
DECLARE @ParentCode AS varchar(40)  --һ����ĿProjCode

--���۷�����һ����Ŀ
SELECT @ProjGUID=ProjGUID
FROM s_DjTjPlan 
WHERE PlanGUID=@PlanGUID

SELECT @ParentCode = ProjCode
FROM p_project
WHERE ProjGUID=@ProjGUID



--����ǰ����ɾ���������ⱨ��Դ��������Ŀ��ֵ������ҵ̬��ֵ������¥����ֵ����
--��¥����Ϣ����������������Ϣ�����������۸��쳣������������㷿����ϸ��
--���ɺ�ˢ��4��ҳǩ�������б�
DELETE s_DjTjResources
WHERE PlanGUID=@PlanGUID

DELETE s_DjTjProjValue
WHERE PlanGUID=@PlanGUID

DELETE s_DjTjYTValue
WHERE PlanGUID=@PlanGUID

DELETE s_DjTjBldValue
WHERE PlanGUID=@PlanGUID
--
DELETE s_DjTjBldAnalysis
WHERE PlanGUID=@PlanGUID

DELETE s_DjTjBatchAnalysis
WHERE PlanGUID=@PlanGUID

DELETE s_DjTjDiscountAbnormal
WHERE PlanGUID=@PlanGUID

DELETE s_DjTjResultDtl
WHERE PlanGUID=@PlanGUID


--SELECT *  
--FROM data_dict dd
--WHERE dd.table_name_c='�۸��쳣�����'

--SELECT * FROM myAction 
--WHERE ObjectType='01010109'

--�Ƿ���ģ��
IF EXISTS(SELECT 1 FROM s_DjTjResult WHERE PlanGUID=@PlanGUID)
BEGIN
	PRINT '�ѵ���۸�'

--���ɱ��α�����Դ���-C1�����ε���ķ��䷶Χ��
select sdt.BldGUID,count(sdt.RoomGUID) as Ts
,sum(isnull((case when isnull(pr.ScBldArea,0)=0 then isnull(pr.YsBldArea,0) else isnull(pr.ScBldArea,0) end ),0)) as BldArea
,isnull((case when isnull(sum(isnull(pr.YsBldArea,0)),0)=0 then 0 else round( sum(isnull(sdt.TotalBu,0))*1.0/sum(pr.YsBldArea),4) end ),0) as TargetAmount
,isnull(sum(isnull(sdt.TotalBu,0)),0) as TargetTotle
,isnull([dbo].[fn_GetHtAllAmount](sdt.BldGUID),0) as HTTotle
,isnull([dbo].[fn_GetHtAllAmount_AreaSum](sdt.BldGUID),0) as HTTotleAreaSum
,sum(isnull((case when isnull(pr.ScBldArea,0)=0 then isnull(pr.YsBldArea,0) else isnull(pr.ScBldArea,0) end ),0)) as PrScYs_AreaSum
--,isnull(sum(isnull(pr.TotalDj,0)),0) as RecentlyTotle
,isnull(sum(ISNULL([dbo].[fn_GetRoomTjfAmountSum](sdt.RoomGUID),0)),0) as RecentlyTotle
,isnull(sum(isnull(sdt.TotalDj,0)),0) as BCRecentlyTotle
,[dbo].[fn_GetJZDateFromSaleBldGUID](sdt.BldGUID) as JZDate
into #tempC1
from s_DjTjResult sdt left join p_room pr
on sdt.RoomGUID=pr.RoomGUID
WHERE PlanGUID=@PlanGUID
group by sdt.BldGUID


insert into s_DjTjResources(DjTjResourcesGUID,PlanGUID,YTName,BldGUID,Ts
,BldArea,TargetAmount,TargetTotle,HTAmount,HTTotle,RecentlyAmount,RecentlyTotle,BCRecentlyAmount,BCRecentlyTotle,JZDate)
select dbo.SeqNewId() AS DjTjResourcesGUID,@PlanGUID,[dbo].[fn_GetYtNameFromBld](BldGUID,'') as YTName,BldGUID,Ts
,BldArea,TargetAmount,TargetTotle
,(case when HTTotleAreaSum=0 then 0 else round( HTTotle*1.0/HTTotleAreaSum,4) end) as HTAmount
,HTTotle
,(case when PrScYs_AreaSum=0 then 0 else round( RecentlyTotle*1.0/PrScYs_AreaSum,4) end) as RecentlyAmount
,RecentlyTotle
,(case when PrScYs_AreaSum=0 then 0 else round( BCRecentlyTotle*1.0/PrScYs_AreaSum,4) end) as BCRecentlyAmount
,BCRecentlyTotle
,(case when JZDate='' then NULL else JZDate end) as JZDate
from #tempC1

--------------[���뱾���޸�����:2014-09-11]-------------

--1.1----------------------------------------------------
--������Ŀ��ֵ(���)-C2
declare @TargetBJArea_Proj_Area as decimal(23,4)=0.0000
declare @TargetDTArea_Proj_Area as decimal(23,4)=0.0000
declare @TZQDT_Proj_Area as decimal(23,4)=0.0000
declare @YTYS_Proj_Area as decimal(23,4)=0.0000
declare @YTWS_Proj_Area as decimal(23,4)=0.0000
declare @BCBP_Proj_Area as decimal(23,4)=0.0000
declare @WTS_Proj_Area as decimal(23,4)=0.0000
declare @XJ_Proj_Area as decimal(23,4)=0.0000

--Ŀ�걨�����					
--TargetBJArea					
--��ǰһ����Ŀ������ĩ����Ŀ������¥������ҵ�ƻ����ys_BusinessPlan����
--��Ӧ�Ĺ���¥����KsArea�������
select @TargetBJArea_Proj_Area=isnull(sum(isnull(gcb.KsArea,0)),0)
FROM dbo.jd_GCBuilding gcb 
where gcb.ProjGUID in (
SELECT ProjGUID FROM p_project WHERE ParentCode=@ParentCode
)

--Ŀ�궯̬���
--TargetDTArea
--��ǰһ����Ŀ������δ���۵Ĺ���¥��ȡ����¥�����е�KsArea�������
--+һ����Ŀ������������¥�����з���Ԥ�������P_ROOM.YsBldArea��֮��
select @TargetDTArea_Proj_Area = isnull(sum(isnull(dbo.fn_CalcBldValue(gcb.BldGUID,'targetdtarea',@PlanGUID),0)),0)
FROM dbo.jd_GCBuilding gcb 
where gcb.ProjGUID in (
SELECT ProjGUID FROM p_project WHERE ParentCode=@ParentCode
)



--����ǰ��ֵ̬
--TZQDT
--��ǰһ����Ŀ������δ����δ���۵Ĺ���¥��ȡ����¥�����е�KsArea�������
--+һ����Ŀ������������¥�����з������½������֮�ͣ���ʵ�������ȡʵ�������ScBldArea����ʵ��Ϊ0��ȡԤ�������													
select @TZQDT_Proj_Area = isnull(sum(isnull(dbo.fn_CalcBldValue(gcb.BldGUID,'tzqdt',@PlanGUID),0)),0)
FROM dbo.jd_GCBuilding gcb 
where gcb.ProjGUID in (
SELECT ProjGUID FROM p_project WHERE ParentCode=@ParentCode
)

--��������					
--YTYS
--��ǰһ����Ŀ�������������۵ķ����ڷ�����ScBldArea�ϼƣ���ScBldAreaΪ0��ȡ�÷����YsBldArea													
select @YTYS_Proj_Area= isnull(sum(isnull(dbo.fn_CalcBldValue(gcb.BldGUID,'ytys_area',@PlanGUID),0)),0)
FROM dbo.jd_GCBuilding gcb 
where gcb.ProjGUID in (
SELECT ProjGUID FROM p_project WHERE ParentCode=@ParentCode
)

--����δ��
--YTWS
--��ǰһ����Ŀ����¥���³����α������ ��������δ�۵ķ����ڷ�����ScBldArea�ϼƣ���ScBldAreaΪ0��ȡ�÷����YsBldArea
select @YTWS_Proj_Area=isnull(sum( case when isnull(ScBldArea,0)=0 then isnull(YsBldArea,0) else isnull(ScBldArea,0) end  ),0)
from p_room
where BldGUID in 
(

	select pb.BldGUID
	FROM p_Building pb 
	where pb.ProjGUID in (
	SELECT ProjGUID FROM p_project WHERE ParentCode=@ParentCode
	) 
	AND  --����¥��
	(
	Not EXISTS(SELECT 1 FROM p_room WHERE BldGUID=pb.BldGUID AND TotalDj=0)
	AND 
	EXISTS(SELECT 1 FROM p_room WHERE BldGUID=pb.BldGUID)
	)
	and pb.IsBld=1
)
and RoomGUID not in (select RoomGUID from s_DjTjResult where PlanGUID=@PlanGUID)
and NOT EXISTS(SELECT 1 FROM s_trade WHERE RoomGUID=p_room.RoomGUID AND TradeStatus='����')
AND Status NOT IN ('�Ϲ�','ǩԼ')

--���α���
--BCBP
--s_DjTjResult��ķ����ScBldArea�ϼƣ���ScBldAreaΪ0��ȡ�÷����YsBldArea													
select @BCBP_Proj_Area=isnull(sum( case when isnull(pr.ScBldArea,0)=0 then isnull(pr.YsBldArea,0) else isnull(pr.ScBldArea,0) end  ) ,0)
from s_DjTjResult sdt left join p_room pr
on sdt.RoomGUID=pr.RoomGUID
where sdt.PlanGUID=@PlanGUID



--δ����
--WTS
--��������[����δ����ļ���]
SELECT @WTS_Proj_Area=ISNULL(SUM(gcb.KsArea),0.00)
FROM dbo.jd_GCBuilding  gcb
--δ�����õ�¥��
WHERE gcb.BldFullCode NOT IN
(
	SELECT p_Building.ParentCode + '.' + p_Building.BldCode
	FROM dbo.p_Project
	INNER JOIN dbo.p_Building ON dbo.p_Building.ProjGUID = dbo.p_Project.ProjGUID
	WHERE p_Project.ParentCode=@ParentCode	--һ����Ŀ������Ŀcode
)
AND gcb.ProjGUID IN
(
	SELECT ProjGUID FROM dbo.p_Project WHERE ParentCode=@ParentCode
)
SELECT @WTS_Proj_Area=@WTS_Proj_Area+ISNULL(SUM(gcb.KsArea),0.00)
FROM dbo.jd_GCBuilding  gcb
--�����õ�¥��,�޷���
WHERE gcb.BldFullCode IN 
(
	SELECT pbld.ParentCode + '.' + pbld.BldCode
	FROM dbo.p_Project proj
	LEFT join dbo.jd_GCBuilding gcb ON gcb.ProjGUID=proj.ProjGUID
	LEFT JOIN dbo.p_Building pbld ON pbld.ParentCode + '.' + pbld.BldCode = gcb.BldFullCode
	LEFT JOIN dbo.p_Room ON dbo.p_Room.BldGUID = pbld.BldGUID
	WHERE proj.ParentCode=@ParentCode AND pbld.BldGUID IS NOT NULL AND p_Room.RoomGUID IS NULL
)
AND gcb.ProjGUID IN
(
	SELECT ProjGUID FROM dbo.p_Project WHERE ParentCode=@ParentCode
)
SELECT @WTS_Proj_Area=@WTS_Proj_Area+ISNULL(SUM(gcb.KsArea),0.00)
FROM dbo.jd_GCBuilding  gcb
--�����ã��з��䣬���ǵ��ܼ�֮��0
WHERE gcb.BldFullCode IN 
(
	SELECT pbld.ParentCode + '.' + pbld.BldCode
	FROM dbo.p_Project proj
	LEFT join dbo.jd_GCBuilding gcb ON gcb.ProjGUID=proj.ProjGUID
	LEFT JOIN dbo.p_Building pbld ON pbld.ParentCode + '.' + pbld.BldCode = gcb.BldFullCode
	LEFT JOIN dbo.p_Room ON dbo.p_Room.BldGUID = pbld.BldGUID
	WHERE proj.ParentCode=@ParentCode AND pbld.BldGUID IS NOT NULL AND p_Room.RoomGUID IS NOT NULL AND p_Room.TotalDj=0
)
AND gcb.ProjGUID IN
(
	SELECT ProjGUID FROM dbo.p_Project WHERE ParentCode=@ParentCode
)
AND gcb.BldFullCode NOT IN
(
	--����ȡ���α����ķ���
	SELECT pbld.ParentCode + '.' + pbld.BldCode
	FROM dbo.s_DjTjResult
	INNER JOIN dbo.p_Building pbld ON pbld.BldGUID = dbo.s_DjTjResult.BldGUID
)
--End Of �������

--С��
--XJ
--��������+����δ��+���α���+δ����
set @XJ_Proj_Area = @YTYS_Proj_Area+@YTWS_Proj_Area+@BCBP_Proj_Area+@WTS_Proj_Area


insert into s_DjTjProjValue(DjTjProjValueGUID,PlanGUID
,TargetBJArea,TargetDTArea
,TZQDT,YTYS,YTWS,BCBP,WTS,XJ
,Sort,ProjGUID)
select dbo.SeqNewId() as DjTjProjValueGUID,@PlanGUID
,@TargetBJArea_Proj_Area,@TargetDTArea_Proj_Area
,@TZQDT_Proj_Area,@YTYS_Proj_Area,@YTWS_Proj_Area,@BCBP_Proj_Area,@WTS_Proj_Area,@XJ_Proj_Area
,1,@ProjGUID



-----------���ϴ���,���ʱ��:2014��9��11��20:11:23
--1.2----------------------------------------------------
--������Ŀ��ֵ(���)-C2
declare @TargetBJArea_Proj_Hz as decimal(23,4)=0.0000
declare @TargetDTArea_Proj_Hz as decimal(23,4)=0.0000
declare @TZQDT_Proj_Hz as decimal(23,4)=0.0000
declare @YTYS_Proj_Hz as decimal(23,4)=0.0000
declare @YTWS_Proj_Hz as decimal(23,4)=0.0000
declare @BCBP_Proj_Hz as decimal(23,4)=0.0000
declare @WTS_Proj_Hz as decimal(23,4)=0.0000
declare @XJ_Proj_Hz as decimal(23,4)=0.0000

--Ŀ�걨�����					
--TargetBJArea					
--��ǰһ����Ŀ������ĩ����Ŀ������¥������ҵ�ƻ����ys_BusinessPlan����
--��Ӧ�����°汾��ÿ��Ԥ��¥���Ļ�׼Ŀ���ܼۣ�ys_BusinessPlanDtl.TotalAmount���ϼ�
select @TargetBJArea_Proj_Area=isnull(sum(isnull(gcb.YSMBTotle,0)),0)
FROM dbo.jd_GCBuilding gcb 
where gcb.ProjGUID in (
SELECT ProjGUID FROM p_project WHERE ParentCode=@ParentCode
)

--Ŀ�궯̬���
--TargetDTArea
--��ǰһ����Ŀ������δ���۵�ȡ��ҵ�ƻ��������°汾����¥���Ļ�׼Ŀ���ܼ�֮��
--+������¥�������з������ҵ�ƻ��ֻ��ܼ�p_room.PlanTotal֮��

select @TargetDTArea_Proj_Area = isnull(sum(isnull(dbo.fn_CalcBldValue(gcb.BldGUID,'targetdtarea_hz',@PlanGUID),0)),0)
FROM dbo.jd_GCBuilding gcb 
where gcb.ProjGUID in (
SELECT ProjGUID FROM p_project WHERE ParentCode=@ParentCode
)


--����ǰ��ֵ̬
--TZQDT
--��ǰһ����Ŀ�������������۷����ܼۺϼ�
--+��������δ�۷����ܼۺϼ�
--+δ���۵Ĺ���¥��YSMBTotle
select @TZQDT_Proj_Hz = ISNULL(sum(isnull(YTYS,0)),0)
from p_room pr left join vs_YTYS_View vsYTYS
on pr.RoomGUID=vsYTYS.RoomGUID
where BldGUID in 
(
	select BldGUID
	FROM p_Building pb 
	where pb.ProjGUID in (
	SELECT ProjGUID FROM p_project WHERE ParentCode=@ParentCode
	) 
	AND --����¥��
	(
	Not EXISTS(SELECT 1 FROM p_room WHERE BldGUID=pb.BldGUID AND TotalDj=0)
	AND 
	EXISTS(SELECT 1 FROM p_room WHERE BldGUID=pb.BldGUID)
	)
	and pb.IsBld=1
)
AND EXISTS(SELECT 1 FROM s_trade WHERE RoomGUID=pr.RoomGUID AND TradeStatus='����')
AND pr.Status IN ('�Ϲ�','ǩԼ')

select @TZQDT_Proj_Hz = @TZQDT_Proj_Hz + isnull(sum(ISNULL([dbo].[fn_GetRoomYTWS](pr.RoomGUID),0)),0)
from p_room pr 
where BldGUID in 
(
	select BldGUID
	FROM p_Building pb 
	where pb.ProjGUID in (
	SELECT ProjGUID FROM p_project WHERE ParentCode=@ParentCode
	) 
	AND --����¥��
	(
	Not EXISTS(SELECT 1 FROM p_room WHERE BldGUID=pb.BldGUID AND TotalDj=0)
	AND 
	EXISTS(SELECT 1 FROM p_room WHERE BldGUID=pb.BldGUID)
	)
	and pb.IsBld=1
)
AND NOT EXISTS(SELECT 1 FROM s_trade WHERE RoomGUID=pr.RoomGUID AND TradeStatus='����')
AND pr.Status NOT IN ('�Ϲ�','ǩԼ')

select @TZQDT_Proj_Hz = @TZQDT_Proj_Hz + isnull(sum(ISNULL([dbo].[fn_CalcBldValue](gcb.BldGUID,'tzqdt_hz',@PlanGUID),0)),0)
FROM dbo.jd_GCBuilding gcb 
where gcb.ProjGUID in (
SELECT ProjGUID FROM p_project WHERE ParentCode=@ParentCode
)



--��������					
--YTYS
--��ǰһ����Ŀ�������������۷����ܼۺϼ�
select @YTYS_Proj_Hz = ISNULL(sum(isnull(YTYS,0)),0)
from p_room pr left join vs_YTYS_View vsYTYS
on pr.RoomGUID=vsYTYS.RoomGUID
where BldGUID in 
(
	select BldGUID
	FROM p_Building pb 
	where pb.ProjGUID in (
	SELECT ProjGUID FROM p_project WHERE ParentCode=@ParentCode
	) 
	AND --����¥��
	(
	Not EXISTS(SELECT 1 FROM p_room WHERE BldGUID=pb.BldGUID AND TotalDj=0)
	AND 
	EXISTS(SELECT 1 FROM p_room WHERE BldGUID=pb.BldGUID)
	)
	and pb.IsBld=1
)
AND EXISTS(SELECT 1 FROM s_trade WHERE RoomGUID=pr.RoomGUID AND TradeStatus='����')
AND pr.Status IN ('�Ϲ�','ǩԼ')

--����δ��
--YTWS
--��ǰһ����Ŀ�³����α������������������δ�۷���ĵ׼��ܼۺϼ�
select @YTWS_Proj_Hz=isnull(sum(ISNULL([dbo].[fn_GetRoomYTWS](RoomGUID),0)),0)
from p_room
where BldGUID in 
(

	select pb.BldGUID
	FROM p_Building pb 
	where pb.ProjGUID in (
	SELECT ProjGUID FROM p_project WHERE ParentCode=@ParentCode
	) 
	and	--����¥��
	(
	Not EXISTS(SELECT 1 FROM p_room WHERE BldGUID=pb.BldGUID AND TotalDj=0)
	AND 
	EXISTS(SELECT 1 FROM p_room WHERE BldGUID=pb.BldGUID)
	)
	and pb.IsBld=1
)
and RoomGUID not in (select RoomGUID from s_DjTjResult where PlanGUID=@PlanGUID)
and NOT EXISTS(SELECT 1 FROM s_trade WHERE RoomGUID=p_room.RoomGUID AND TradeStatus='����')
AND Status NOT IN ('�Ϲ�','ǩԼ')

--���α���
--BCBP
--s_DjTjResult��ķ���ĵ׼��ܼ�TotalDj�ϼ�												
select @BCBP_Proj_Hz=isnull(sum( isnull(sdt.TotalDj,0)) ,0)
from s_DjTjResult sdt 
where sdt.PlanGUID=@PlanGUID

--δ����
--WTS
--��������[����δ����ļ���]
SELECT @WTS_Proj_Hz=ISNULL(SUM(gcb.YSMBTotle),0.00)
FROM dbo.jd_GCBuilding  gcb
--δ�����õ�¥��
WHERE gcb.BldFullCode NOT IN
(
	SELECT p_Building.ParentCode + '.' + p_Building.BldCode
	FROM dbo.p_Project
	INNER JOIN dbo.p_Building ON dbo.p_Building.ProjGUID = dbo.p_Project.ProjGUID
	WHERE p_Project.ParentCode=@ParentCode	--һ����Ŀ������Ŀcode
)
AND gcb.ProjGUID IN
(
	SELECT ProjGUID FROM dbo.p_Project WHERE ParentCode=@ParentCode
)
SELECT @WTS_Proj_Hz=@WTS_Proj_Hz+ISNULL(SUM(gcb.YSMBTotle),0.00)
FROM dbo.jd_GCBuilding  gcb
--�����õ�¥��,�޷���
WHERE gcb.BldFullCode IN 
(
	SELECT pbld.ParentCode + '.' + pbld.BldCode
	FROM dbo.p_Project proj
	LEFT join dbo.jd_GCBuilding gcb ON gcb.ProjGUID=proj.ProjGUID
	LEFT JOIN dbo.p_Building pbld ON pbld.ParentCode + '.' + pbld.BldCode = gcb.BldFullCode
	LEFT JOIN dbo.p_Room ON dbo.p_Room.BldGUID = pbld.BldGUID
	WHERE proj.ParentCode=@ParentCode AND pbld.BldGUID IS NOT NULL AND p_Room.RoomGUID IS NULL
)
AND gcb.ProjGUID IN
(
	SELECT ProjGUID FROM dbo.p_Project WHERE ParentCode=@ParentCode
)
SELECT @WTS_Proj_Hz=@WTS_Proj_Hz+ISNULL(SUM(gcb.YSMBTotle),0.00)
FROM dbo.jd_GCBuilding  gcb
--�����ã��з��䣬���ǵ��ܼ�֮��0
WHERE gcb.BldFullCode IN 
(
	SELECT pbld.ParentCode + '.' + pbld.BldCode
	FROM dbo.p_Project proj
	LEFT join dbo.jd_GCBuilding gcb ON gcb.ProjGUID=proj.ProjGUID
	LEFT JOIN dbo.p_Building pbld ON pbld.ParentCode + '.' + pbld.BldCode = gcb.BldFullCode
	LEFT JOIN dbo.p_Room ON dbo.p_Room.BldGUID = pbld.BldGUID
	WHERE proj.ParentCode=@ParentCode AND pbld.BldGUID IS NOT NULL AND p_Room.RoomGUID IS NOT NULL AND p_Room.TotalDj=0
)
AND gcb.ProjGUID IN
(
	SELECT ProjGUID FROM dbo.p_Project WHERE ParentCode=@ParentCode
)
AND gcb.BldFullCode NOT IN
(
	--����ȡ���α����ķ���
	SELECT pbld.ParentCode + '.' + pbld.BldCode
	FROM dbo.s_DjTjResult
	INNER JOIN dbo.p_Building pbld ON pbld.BldGUID = dbo.s_DjTjResult.BldGUID
)
--End Of �������

--С��
--XJ
--��������+����δ��+���α���+δ����
set @XJ_Proj_Hz = @YTYS_Proj_Hz+@YTWS_Proj_Hz+@BCBP_Proj_Hz+@WTS_Proj_Hz

insert into s_DjTjProjValue(DjTjProjValueGUID,PlanGUID
,TargetBJArea,TargetDTArea
,TZQDT,YTYS,YTWS,BCBP,WTS,XJ
,Sort,ProjGUID)
select dbo.SeqNewId() as DjTjProjValueGUID,@PlanGUID
,@TargetBJArea_Proj_Hz,@TargetDTArea_Proj_Hz
,@TZQDT_Proj_Hz,@YTYS_Proj_Hz,@YTWS_Proj_Hz,@BCBP_Proj_Hz,@WTS_Proj_Hz,@XJ_Proj_Hz
,2,@ProjGUID



---------���ϣ���ɣ�2014��9��11��20:48:26
--1.3.1---------------------------------------------------
--����¥����ֵ�������-C3

--TargetBJArea
--����¥������ҵ�ƻ����ys_BusinessPlan���ж�Ӧ�����°汾��Ԥ��¥���Ľ��������ys_BusinessPlanDtl.BldArea��
--TargetDTArea
--¥��δ����ȡ��ҵ�ƻ��������°汾��¥���������,¥��������ȡ¥�������з���Ԥ�����֮��p_room.YsBldArea
--TZQDT
--¥��δ����ȡ��ҵ�ƻ��������°汾��¥���������
--¥��������ȡ¥�������з���ʵ�����p_room.ScBldArea֮�ͣ�ʵ�����Ϊ0ȡ�����Ԥ�������
--YTYS
--¥���������������۵ķ����ڷ�����ScBldArea�ϼƣ���ScBldAreaΪ0��ȡ�÷����YsBldArea
--YTWS
--¥���³����α��������������δ�۵ķ����ڷ�����ScBldArea�ϼƣ���ScBldAreaΪ0��ȡ�÷����YsBldArea

--BCBP
--s_DjTjResult��ķ����ScBldArea�ϼƣ���ScBldAreaΪ0��ȡ�÷����YsBldArea
--WTS
--¥��δ�����Ҳ��ڱ��α����ڣ�ȡ��ҵ�ƻ��������°汾��¥���������(���ȷ�Ͼ���0)
--¥��������ȡ0
--XJ
--��������+����δ��+���α���+δ����

select 
gcb.BldGUID,gcb.ProductGUID
,isnull(gcb.KsArea,0) as TargetBJArea
,isnull(dbo.fn_CalcBldValue(gcb.BldGUID,'targetdtarea',@PlanGUID),0) as TargetDTArea
,isnull(dbo.fn_CalcBldValue(gcb.BldGUID,'tzqdt',@PlanGUID),0) as TZQDT
,isnull(dbo.fn_CalcBldValue(gcb.BldGUID,'ytys_area',@PlanGUID),0) as YTYS
,isnull(dbo.fn_CalcBldValue(gcb.BldGUID,'ytws_area',@PlanGUID),0) as YTWS
,isnull(dbo.fn_CalcBldValue(gcb.BldGUID,'bcbp_area_any',@PlanGUID),0) as BCBP
,(case when [dbo].[fn_IsWTsBldAndNoBcPlan](gcb.BldGUID,@PlanGUID)=1 then CONVERT(MONEY,1) else 0 end ) as WTS
,cast(0 as decimal(23,4)) as XJ
,dbo.[fn_GetYtNameFromBld](gcb.BldGUID,'gcbuilding') as YTName
into #tempC3_Area
FROM dbo.jd_GCBuilding gcb
where gcb.ProjGUID in (
SELECT ProjGUID FROM p_project WHERE ParentCode=@ParentCode
)


--******sunsoft area************
--��WTS��ֵ�����ݹ���¥������������¥��
	UPDATE #tempC3_Area
	SET WTS=source.KsArea
	FROM
	(
		SELECT ISNULL(gcb.KsArea,0.00) KsArea , gcb.BldGUID
		FROM 
		dbo.jd_GCBuilding gcb
	) source
	WHERE source.BldGUID=#tempC3_Area.BldGUID AND #tempC3_Area.WTS=1
--******************

update #tempC3_Area
set XJ=(YTYS+YTWS+BCBP+WTS)




insert into s_DjTjBldValue(DjTjBldValueGUID,PlanGUID,TargetBJArea,TargetDTArea,TZQDT
,YTYS,YTWS,BCBP,WTS,XJ
,BldGUID,YTGUID,Sort,ProjGUID)
select dbo.SeqNewId() as DjTjBldValueGUID,@PlanGUID,TargetBJArea,TargetDTArea,TZQDT
,YTYS,YTWS,BCBP,WTS
,(YTYS+YTWS+BCBP+WTS) as XJ
,BldGUID
,ProductGUID as YTGUID, 1 as Sort,@ProjGUID
from #tempC3_Area



--1.3.3---------------------------------------------------
--����¥����ֵ����ֵ��-C3
--TargetBJArea
--����¥������ҵ�ƻ����ys_BusinessPlan���ж�Ӧ�����°汾��Ԥ��¥���Ļ�׼Ŀ���ܼۣ�ys_BusinessPlanDtl.TotalAmount��
--TargetDTArea
--¥��δ����ȡ��ҵ�ƻ��������°汾��¥����׼Ŀ���ܼ�
--¥��������ȡ¥�������з�����ҵ�ƻ��ܼ�p_room.PlanTotal
--TZQDT
--¥��δ����ȡ��ҵ�ƻ��������°汾��¥����׼Ŀ���ܼ�
--¥��������ȡ¥���������������۵ķ����ܼۺϼ�+����δ�۵ķ����ܼۺϼ�
--YTYS
--¥���������������۵ķ����ܼۺϼ�
--YTWS
--¥���³����α��������������δ�۵ķ����ܼۺϼ�

--BCBP
--s_DjTjResult��ķ���ĵ׼��ܼ�TotalDj�ϼ�
--WTS
--¥��δ�����Ҳ��ڱ��α����ڣ�ȡ��ҵ�ƻ��������°汾��¥����׼Ŀ���ܼ�(���ȷ�Ͼ���0)
--¥��������ȡ0
--XJ
--��������+����δ��+���α���+δ����

select 
gcb.BldGUID,gcb.ProductGUID
,isnull(gcb.YSMBTotle,0) as TargetBJArea
,isnull(dbo.fn_CalcBldValue(gcb.BldGUID,'targetdtarea_hz',@PlanGUID),0) as TargetDTArea
,isnull(dbo.fn_CalcBldValue(gcb.BldGUID,'tzqdt_hz_special',@PlanGUID),0) as TZQDT

,isnull(dbo.fn_CalcBldValue(gcb.BldGUID,'ytys_hz',@PlanGUID),0) as YTYS
,isnull(dbo.fn_CalcBldValue(gcb.BldGUID,'ytws_hz',@PlanGUID),0) as YTWS

,isnull(dbo.fn_CalcBldValue(gcb.BldGUID,'bcbp_hz_any',@PlanGUID),0) as BCBP
,(case when [dbo].[fn_IsWTsBldAndNoBcPlan](gcb.BldGUID,@PlanGUID)=1 then CONVERT(MONEY,1) else 0 end ) as WTS
,cast(0 as decimal(23,4)) as XJ
,dbo.[fn_GetYtNameFromBld](gcb.BldGUID,'gcbuilding') as YTName  --��������p_BuildProductType��level=2��
into #tempC3_Hz
FROM dbo.jd_GCBuilding gcb
where gcb.ProjGUID in (
SELECT ProjGUID FROM p_project WHERE ParentCode=@ParentCode
)


--******sunsoft area************
--��WTS��ֵ�����ݹ���¥������������¥��
	UPDATE #tempC3_Hz
	SET #tempC3_Hz.WTS=source.YSMBTotle
	FROM
	(
		SELECT ISNULL(gcb.YSMBTotle,0.00) YSMBTotle , gcb.BldGUID
		FROM 
		dbo.jd_GCBuilding gcb
	) source
	WHERE source.BldGUID=#tempC3_Hz.BldGUID AND #tempC3_Hz.WTS=1
--******************


update #tempC3_Hz
set XJ=(YTYS+YTWS+BCBP+WTS)


insert into s_DjTjBldValue(DjTjBldValueGUID,PlanGUID,TargetBJArea,TargetDTArea,TZQDT
,YTYS,YTWS,BCBP,WTS,XJ
,BldGUID,YTGUID,Sort,ProjGUID)
select dbo.SeqNewId() as DjTjBldValueGUID,@PlanGUID,TargetBJArea,TargetDTArea,TZQDT
,YTYS,YTWS,BCBP,WTS
,(YTYS+YTWS+BCBP+WTS) as XJ
,BldGUID
,ProductGUID as YTGUID, 3 as Sort,@ProjGUID
from #tempC3_Hz

--1.3.2---------------------------------------------------
--����¥����ֵ�����ۣ�-C3

--¥���Ļ�ֵ/���
insert into s_DjTjBldValue(DjTjBldValueGUID,PlanGUID,TargetBJArea,TargetDTArea,TZQDT
,YTYS,YTWS,BCBP,WTS,XJ
,BldGUID,YTGUID,Sort,ProjGUID)
select dbo.SeqNewId() as DjTjBldValueGUID,@PlanGUID
,(case when b.TargetBJArea=0 then 0 else round( a.TargetBJArea*1.0/b.TargetBJArea,4) end) as TargetBJArea
,(case when b.TargetDTArea=0 then 0 else round( a.TargetDTArea*1.0/b.TargetDTArea,4) end) as TargetDTArea
,(case when b.TZQDT=0 then 0 else round( a.TZQDT*1.0/b.TZQDT,4) end) as TZQDT
,(case when b.YTYS=0 then 0 else round( a.YTYS*1.0/b.YTYS,4) end) as YTYS
,(case when b.YTWS=0 then 0 else round( a.YTWS*1.0/b.YTWS,4) end) as YTWS
,(case when b.BCBP=0 then 0 else round( a.BCBP*1.0/b.BCBP,4) end) as BCBP
,(case when b.WTS=0 then 0 else round( a.WTS*1.0/b.WTS,4) end) as WTS
,(case when b.XJ=0 then 0 else round( a.XJ*1.0/b.XJ,4) end) as XJ
,a.BldGUID
,(case when a.ProductGUID is null then b.ProductGUID else a.ProductGUID end) as YTGUID
, 2 as Sort
,@ProjGUID
from #tempC3_Hz a left join #tempC3_Area b
on a.BldGUID=b.BldGUID

--1.4.1---------------------------------------------------
--����ҵ̬��ֵ�������-C4
--����һ����Ŀ�ĸ�ҵ̬������¥���Ķ�Ӧָ��ϼ�

--ҵ̬(cb_HkbProductWork.ProductGUID)���� ��Ʒ����(cb_HkbProductWork.ProductName,cb_HkbProductWork.BProductTypeCode)��
--���Զ��ҵ̬���Թ���ͬһ����Ʒ������

select 
( SELECT top 1 BuildProductTypeGUID FROM p_BuildProductType WHERE LEVEL=2 and BProductTypeShortName=#tempC3_Area.YTName ) as YTGUID  --level2�²����ظ�
,sum(round(isnull(TargetBJArea,0),4)) as TargetBJArea
,sum(round(isnull(TargetDTArea,0),4)) as TargetDTArea
,sum(round(isnull(TZQDT,0),4)) as TZQDT
,sum(round(isnull(YTYS,0),4)) as YTYS
,sum(round(isnull(YTWS,0),4)) as YTWS
,sum(round(isnull(BCBP,0),4)) as BCBP
,sum(round(isnull(WTS,0),4)) as WTS
,sum(round(isnull(XJ,0),4)) as XJ
into #tempC3_Area_Yt
from #tempC3_Area
--group by ProductGUID
group by YTName

insert into s_DjTjYTValue(DjTjYTValueGUID,PlanGUID
,TargetBJArea
,TargetDTArea
,TZQDT,YTYS,YTWS,BCBP,WTS,XJ
,YTGUID,Sort,ProjGUID)
select dbo.SeqNewId() as DjTjYTValueGUID,@PlanGUID as PlanGUID
,TargetBJArea
,TargetDTArea
,TZQDT,YTYS,YTWS,BCBP,WTS,XJ
,YTGUID
,1 as Sort
,@ProjGUID as ProjGUID 
from #tempC3_Area_Yt



--select * from #tempC3_Hz
--order by bldguid
--1.4.2---------------------------------------------------
--����ҵ̬��ֵ����ֵ��-C4
--����һ����Ŀ�ĸ�ҵ̬������¥���Ķ�Ӧָ��ϼ�
select 
--ProductGUID as YTGUID
( SELECT top 1 BuildProductTypeGUID FROM p_BuildProductType WHERE LEVEL=2 and BProductTypeShortName=#tempC3_Hz.YTName ) as YTGUID  --level2�²����ظ�
,sum(round(isnull(TargetBJArea,0),4)) as TargetBJArea
,sum(round(isnull(TargetDTArea,0),4)) as TargetDTArea
,sum(round(isnull(TZQDT,0),4)) as TZQDT
,sum(round(isnull(YTYS,0),4)) as YTYS
,sum(round(isnull(YTWS,0),4)) as YTWS
,sum(round(isnull(BCBP,0),4)) as BCBP
,sum(round(isnull(WTS,0),4)) as WTS
,sum(round(isnull(XJ,0),4)) as XJ
into #tempC3_Hz_Yt
from #tempC3_Hz
--group by ProductGUID
group by YTName


insert into s_DjTjYTValue(DjTjYTValueGUID,PlanGUID
,TargetBJArea
,TargetDTArea
,TZQDT,YTYS,YTWS,BCBP,WTS,XJ
,YTGUID,Sort,ProjGUID)
select dbo.SeqNewId() as DjTjYTValueGUID,@PlanGUID as PlanGUID
,TargetBJArea
,TargetDTArea
,TZQDT,YTYS,YTWS,BCBP,WTS,XJ
,YTGUID
,3 as Sort
,@ProjGUID as ProjGUID 
from #tempC3_Hz_Yt

--select * from #tempC3_Hz_Yt
--order by YTGUID
--select * from #tempC3_Area_Yt
--order by YTGUID
--1.4.3---------------------------------------------------
--����ҵ̬��ֵ�����ۣ�-C4
--ҵ̬�Ļ�ֵ/���
insert into s_DjTjYTValue(DjTjYTValueGUID,PlanGUID
,TargetBJArea
,TargetDTArea
,TZQDT,YTYS,YTWS,BCBP,WTS,XJ
,YTGUID,Sort,ProjGUID)
select dbo.SeqNewId() as DjTjBldValueGUID,@PlanGUID
,round((case when b.TargetBJArea=0 then 0 else a.TargetBJArea*1.0/b.TargetBJArea end),4) as TargetBJArea
,round((case when b.TargetDTArea=0 then 0 else a.TargetDTArea*1.0/b.TargetDTArea end),4) as TargetDTArea
,round((case when b.TZQDT=0 then 0 else a.TZQDT*1.0/b.TZQDT end),4) as TZQDT
,round((case when b.YTYS=0 then 0 else a.YTYS*1.0/b.YTYS end),4) as YTYS
,round((case when b.YTWS=0 then 0 else a.YTWS*1.0/b.YTWS end),4) as YTWS
,round((case when b.BCBP=0 then 0 else a.BCBP*1.0/b.BCBP end),4) as BCBP
,round((case when b.WTS=0 then 0 else a.WTS*1.0/b.WTS end),4) as WTS
,round((case when b.XJ=0 then 0 else a.XJ*1.0/b.XJ end),4) as XJ
,(case when a.YTGUID is null then b.YTGUID else a.YTGUID end) as YTGUID
, 2 as Sort
,@ProjGUID
from #tempC3_Hz_Yt a left join #tempC3_Area_Yt b
on a.YTGUID=b.YTGUID



--1.4.3---------------------------------------------------
--����¥����Ϣ����-C5
--Ts:��¥��ά�Ȼ���s_DjTjResult����ÿ��¥���±����ϱ��ķ�������
--BldArea:��¥��ά�Ȼ���s_DjTjResult����ÿ��¥���±����ϱ��ķ����ڷ�����ʵ�⽨�����p_room.ScBldArea��ʵ��Ϊ0ȡԤ�۽������YsBldArea��
--ZTs:��¥��ά�Ȼ���ÿ��¥����������
--ZBldArea:��¥��ά�Ȼ���ÿ��¥�������з����ڷ�����Ԥ�۽������p_room.YsBldArea
--BuAmount:ȡ��ҵ�ƻ��������°汾��¥����׼Ŀ�굥��ys_BusinessPlanDtl.Amount
--BuTotle:ȡ��ҵ�ƻ��������°汾��¥����׼Ŀ���ܼ�ys_BusinessPlanDtl.TotalAmount
--FHAmount:ȡ¥���б����ϱ��ķ�Դ����ҵ�ƻ��ֻ��ܼ�֮��s_DjTjResult.TotalBu/��Ӧ�����Ԥ�����p_room.Ysbldarea֮��
--FHTotle:ȡ¥���б����ϱ��ķ�Դ����ҵ�ƻ��ֻ��ܼ�s_DjTjResult.TotalBu�ϼ�
--HTAmount:¥���������������۵ķ����ܼۺϼ�/�����ʵ�⽨������ϼ�p_room.ScBldArea��ʵ�����Ϊ0ȡԤ�۽��������
--HTTotle:¥���������������۵ķ����ܼۺϼ�
--RecentlyAmount:ȡ¥�������з����ڷ����ĵ׼��ܼ�p_room.TotleDj�ϼƣ����������Ч�ؼ�ʱ��ǰϵͳʱ�����ؼ���Ч��ʧЧ���ڼ䣬ȡTotalTj��
--/��Ӧ����ʵ�⽨�����p_room.ScBldArea֮�ͣ�ʵ��Ϊ0ȡԤ�ۣ�
--RecentlyTotle:ȡ¥�������з����ڷ����ĵ׼��ܼ�p_room.TotleDj�ϼƣ����������Ч�ؼ�ʱ��ǰϵͳʱ�����ؼ���Ч��ʧЧ���ڼ䣬ȡTotalTj��
--BCRecentlyAmount:ȡ¥���У�����δ�ϱ��ķ����ڷ����׼��ܼ�p_room.TotleDj�ϼ�+���ε���������s_DjTjResult�׼��ܼ�TotleDj�ϼƣ�
--/��Ӧ����ʵ�⽨�����p_room.ScBldArea֮�ͣ���ʵ��ȡԤ�ۣ�
--BCRecentlyTotle:ȡ¥���б���δ�ϱ��ķ����ڷ����׼��ܼ�+���ε���������s_DjTjResult�׼��ܼ�

insert into s_DjTjBldAnalysis(DjTjBldAnalysisGUID,PlanGUID
,YTName,BldGUID
,Ts,BldArea,ZTs,ZBldArea,BuAmount,BuTotle
,FHAmount,FHTotle,HTAmount,HTTotle
,RecentlyAmount,RecentlyTotle,BCRecentlyAmount,BCRecentlyTotle)
--/*
select dbo.SeqNewId() as DjTjBldAnalysisGUID,@PlanGUID
,a.YTName,a.BldGUID
,a.Ts
,a.BldArea
,b.ZTs
,b.ZBldArea
,a.BuAmount
,a.BuTotle
,a.FHAmount
,a.FHTotle
--HTAmount:¥���������������۵ķ����ܼۺϼ�/�����ʵ�⽨������ϼ�p_room.ScBldArea��ʵ�����Ϊ0ȡԤ�۽��������
,(case when isnull(b.HTTotleAreaSum,0)=0 then 0 else round( isnull(b.HTTotle,0)*1.0/b.HTTotleAreaSum,4) end) as HTAmount
,b.HTTotle
,(case when isnull(b.ScYsBldArea,0)=0 then 0 else round( isnull(b.RecentlyTotle,0)*1.0/b.ScYsBldArea,4) end) as RecentlyAmount
,b.RecentlyTotle
--BCRecentlyAmount:ȡ¥���У�����δ�ϱ��ķ����ڷ����׼��ܼ�(���ؼ۷��߼�ȡ��)�ϼ�+���ε���������s_DjTjResult�׼��ܼ�TotleDj�ϼƣ�
--/��Ӧ����ʵ�⽨�����p_room.ScBldArea֮�ͣ���ʵ��ȡԤ�ۣ�
,(case when isnull(b.ScYsBldArea,0)=0 then 0 else round( (isnull(c.BCRecentlyTotle_WSB,0)+isnull(a.BCRecentlyTotle_BCTZ,0))*1.0/b.ScYsBldArea,4) end) as BCRecentlyAmount
--BCRecentlyTotle:ȡ¥���б���δ�ϱ��ķ����ڷ����׼��ܼ�+���ε���������s_DjTjResult�׼��ܼ�
,(isnull(c.BCRecentlyTotle_WSB,0)+isnull(a.BCRecentlyTotle_BCTZ,0)) as BCRecentlyTotle
--,isnull(c.BCRecentlyTotle_WSB,0),isnull(a.BCRecentlyTotle_BCTZ,0)
from 
(
--¥���±����ϱ�����
select dbo.[fn_GetYtNameFromBld](sdt.BldGUID,'') as YTName,sdt.BldGUID
,count(sdt.RoomGUID) as Ts
,isnull(sum( case when isnull(pr.ScBldArea,0)=0 then isnull(pr.YsBldArea,0) else isnull(pr.ScBldArea,0) end  ) ,0) as BldArea
,isnull([dbo].[fn_getSlxtBldPrice](sdt.BldGUID,'Amount'),0) as BuAmount
,isnull([dbo].[fn_getSlxtBldPrice](sdt.BldGUID,'TotalAmount'),0) as BuTotle
,(case when isnull(sum(isnull(pr.YsBldArea,0)),0)=0 then 0 else round( isnull(sum(isnull(sdt.TotalBu,0)),0)*1.0/isnull(sum(isnull(pr.YsBldArea,0)),0),4) end) as FHAmount
,isnull(sum(isnull(sdt.TotalBu,0)),0) as FHTotle
,isnull(sum( isnull(sdt.TotalDj,0) ) ,0) as BCRecentlyTotle_BCTZ
from s_DjTjResult sdt left join p_room pr
on sdt.RoomGUID=pr.RoomGUID
where sdt.PlanGUID=@PlanGUID
group by sdt.BldGUID  
) a
left join (
--¥�������з���
select pr.BldGUID
,count(1) as ZTs
,isnull(sum(isnull(pr.YsBldArea,0)),0) as ZBldArea
,isnull(sum(isnull([dbo].[fn_GetRoomTjfAmountSum](pr.RoomGUID),0)),0) as RecentlyTotle
,isnull(sum( case when isnull(pr.ScBldArea,0)=0 then isnull(pr.YsBldArea,0) else isnull(pr.ScBldArea,0) end  ) ,0) as ScYsBldArea
--HTTotle:¥���������������۵ķ����ܼۺϼ�
,ISNULL(sum(isnull(vsYTYS.YTYS,0)),0) as HTTotle
,isnull(sum(vsYTYS.ScYsAreaSum),0) as HTTotleAreaSum
from p_room pr left join vs_YTYS_View vsYTYS
on pr.RoomGUID=vsYTYS.RoomGUID 
where pr.BldGUID in (select BldGUID from s_DjTjResult where PlanGUID=@PlanGUID)
group by pr.BldGUID	
) b
on a.BldGUID=b.BldGUID
left join (
--¥���±���δ�ϱ�����
select BldGUID
,isnull(sum(isnull(dbo.[fn_GetRoomTjfAmountSum](RoomGUID),0)),0) as BCRecentlyTotle_WSB		--�Ƿ��ؼ۷�
--BCRecentlyTotle:ȡ¥���б���δ�ϱ��ķ����ڷ����׼��ܼ�(���ؼ۷��߼�ȡ��BCRecentlyTotle_WSB)+���ε���������s_DjTjResult�׼��ܼ�
from p_room 
where BldGUID in (select BldGUID from s_DjTjResult where PlanGUID=@PlanGUID)
and RoomGUID not in (select RoomGUID from s_DjTjResult where PlanGUID=@PlanGUID)
group by BldGUID	
) c
on a.BldGUID=c.BldGUID

--*/



END
ELSE
BEGIN
	PRINT 'δ����۸�'
	
	--���ɼ۸��쳣����-C7
	--ѭ����ǰ���۷�������һ����Ŀ�µ����з��䣬�ж�ÿ�����������Żݺ��ܼ��Ƿ���ڷ���ĵ׼��ܼۣ�
	--����ڵ׼��ܼۣ������±���뷿���¼

--	


END

 
--���ɼ۸��쳣����-C7
--����Żݺ��ܼ�:
--�������׼�ܼۣ������ڱ��ε��۷�����s_DjTjResult����ȡs_DjTjResult����ֱ�׼�ܼ�Total
--������ȡ�����ı�׼�ܼ�Total��-���Żݽ�*��1-���Żݼ��㣩
--DECLARE @PlanGUID AS varchar(40)='2B721174-9DBB-E311-80DB-00155D0A6F0B'

--����ĵ׼��ܼ�:TotalDj	�׼��ܼ�
SELECT --TOP 1 
dbo.[fn_GetYtNameFromBld](pr.BldGUID,'') as YTName
,pr.BldGUID,pr.RoomGUID
,(CASE WHEN isnull(pr.ScBldArea,0)=0 THEN isnull(pr.YsBldArea,0) ELSE pr.ScBldArea end) AS BldArea
,(CASE WHEN isnull(pr.ScTnArea,0)=0 THEN isnull(pr.YsTnArea,0) ELSE pr.ScTnArea end) AS TnArea
,(CASE WHEN sdt.PriceDj IS NULL THEN pr.PriceDj ELSE sdt.PriceDj END ) AS DjBldAmount
,(CASE WHEN sdt.TnPriceDj IS NULL THEN pr.TnPriceDj ELSE sdt.TnPriceDj END ) AS DjTnAmount
,(CASE WHEN sdt.TotalDj IS NULL THEN pr.TotalDj ELSE sdt.TotalDj END ) AS DjTotle
,isnull(pb.YHPoint,0) AS DiscountPoint 
,isnull(pb.YHAmount,0) AS DiscountAmount
--�������ı�׼�ܼ�Total-��������¥����¥�������p_Building.YHAmount��*��1-��������¥����¥������p_Building.YHPoint��!�������100
,(isnull(pr.Total,0)-isnull(pb.YHAmount,0) )*(1.00-isnull(pb.YHPoint,0)/100.00) AS DiscountTotle
,[dbo].[fn_GetNowDiscountPoint](@PlanGUID,pr.BldGUID) AS NowDiscountPoint
,[dbo].[fn_GetNowDiscountAmount](@PlanGUID,pr.BldGUID) AS NowDiscountAmount
,(CASE WHEN sdt.Price IS NULL THEN pr.Price ELSE sdt.Price END ) AS BZBldAmount
,(CASE WHEN sdt.TnPrice IS NULL THEN pr.TnPrice ELSE sdt.TnPrice END ) AS BZTnAmount
,(CASE WHEN sdt.Total IS NULL THEN pr.Total ELSE sdt.Total END ) AS BZTotle

INTO #tempC7
FROM p_room pr LEFT JOIN 
(
SELECT RoomGUID,PriceDj,TnPriceDj,TotalDj,Price,TnPrice,Total 
FROM s_DjTjResult	
WHERE PlanGUID=@PlanGUID
) sdt
ON pr.RoomGUID=sdt.RoomGUID
LEFT JOIN p_Building pb 
ON pr.BldGUID=pb.BldGUID
WHERE pr.ProjGUID IN (SELECT ProjGUID FROM p_project WHERE ParentCode=@ParentCode)
and pb.IsBld=1

--�����˵��������۵ķ��䣩
INSERT INTO s_DjTjDiscountAbnormal(DjTjDiscountAbnormalGUID,PlanGUID,YTName,BldGUID,RoomGUID,BldArea,TnArea,DjBldAmount,DjTnAmount
,DjTotle,DiscountPoint,DiscountAmount,DiscountTotle,NowDiscountPoint
,NowDiscountAmount,BZBldAmount,BZTnAmount,BZTotle,NowDiscountTotle)
SELECT dbo.SeqNewId() AS DjTjDiscountAbnormalGUID,@PlanGUID,YTName,BldGUID,RoomGUID,BldArea,TnArea,DjBldAmount,DjTnAmount
,DjTotle,DiscountPoint,DiscountAmount,DiscountTotle,NowDiscountPoint,NowDiscountAmount
,BZBldAmount,BZTnAmount,BZTotle
,(isnull(BZTotle,0)-isnull(NowDiscountAmount,0))*(1-isnull(NowDiscountPoint,0)/100.00) AS NowDiscountTotle
FROM #tempC7
WHERE (isnull(BZTotle,0)-isnull(NowDiscountAmount,0))*(1-isnull(NowDiscountPoint,0)/100.00)<(isnull(DjTotle,0)-1)
AND RoomGUID NOT IN 
(
		SELECT pr.RoomGUID
		from p_room pr INNER JOIN #tempC7
		ON pr.RoomGUID=#tempC7.RoomGUID
		where --RoomGUID =  #tempC7.RoomGUID AND 
		 --����¥��
		(
		Not EXISTS(SELECT 1 FROM p_room WHERE BldGUID=pr.BldGUID AND TotalDj=0)
		AND 
		EXISTS(SELECT 1 FROM p_room WHERE BldGUID=pr.BldGUID)
		)
		AND EXISTS(SELECT 1 FROM s_trade WHERE RoomGUID=pr.RoomGUID AND TradeStatus='����')
		AND Status IN ('�Ϲ�','ǩԼ')
)

--���ɷ�����ϸ-C8
SELECT sdt.PlanGUID,pr.BldGUID,sdt.RoomGUID,pr.BldArea,pr.TnArea
,sdt.PriceBu,sdt.TnPriceBu,sdt.TotalBu
,sdt.OriginalPriceDj,sdt.OriginalTnPriceDj,sdt.OriginalTotalDj,sdt.PriceDj,sdt.TnPriceDj,sdt.TotalDj,sdt.OriginalPrice
,sdt.OriginalTnPrice,sdt.OriginalToTal,sdt.Price,sdt.TnPrice,sdt.ToTal
,[dbo].[fn_GetNowDiscount_YCXJD](sdt.PlanGUID,pr.BldGUID) AS YCXJD
,[dbo].[fn_GetNowDiscount_JDBL](sdt.PlanGUID) AS ASYHJD
,[dbo].[fn_GetNowDiscount_BCPointAmount](sdt.PlanGUID,pr.BldGUID,'BCPoint') AS CXJD
,[dbo].[fn_GetNowDiscount_BCPointAmount](sdt.PlanGUID,pr.BldGUID,'BCAmount') AS CXJE
--����׼�ܼ�-�����Żݣ�����*��1-һ���Ը����Ż�-��ʱǩԼ�Ż�-�����Żݼ��㣩
--,( (ToTal-dbo.[fn_GetNowDiscount_BCPointAmount](sdt.PlanGUID,pr.BldGUID,'BCAmount'))*(1-[dbo].[fn_GetNowDiscount_YCXJD](sdt.PlanGUID,pr.BldGUID)
--						-[dbo].[fn_GetNowDiscount_JDBL](sdt.PlanGUID)-[dbo].[fn_GetNowDiscount_BCPointAmount](sdt.PlanGUID,pr.BldGUID,'BCPoint'))  ) AS ZDYHZJ 
INTO #tempC8
FROM s_DjTjResult sdt LEFT JOIN p_room pr
ON sdt.RoomGUID=pr.RoomGUID
WHERE sdt.PlanGUID=@PlanGUID


INSERT INTO s_DjTjResultDtl(DjTjResultDtlGUID,PlanGUID,BldGUID,RoomGUID,BldArea,TnArea,PriceBu,TnPriceBu,TotalBu
,OriginalPriceDj,OriginalTnPriceDj,OriginalTotalDj,PriceDj,TnPriceDj,TotalDj,OriginalPrice
,OriginalTnPrice,OriginalToTal,Price,TnPrice,ToTal
,YCXJD,ASYHJD,CXJD,CXJE,ZDYHZJ
)
SELECT dbo.SeqNewId() AS DjTjResultDtlGUID,PlanGUID,BldGUID,RoomGUID,BldArea,TnArea,PriceBu,TnPriceBu,TotalBu
,OriginalPriceDj,OriginalTnPriceDj,OriginalTotalDj,PriceDj,TnPriceDj,TotalDj,OriginalPrice
,OriginalTnPrice,OriginalToTal,Price,TnPrice,ToTal
,YCXJD,ASYHJD,CXJD,CXJE
,( (ToTal-CXJE)*(1-YCXJD/100.00-ASYHJD/100.00-CXJD/100.00) ) AS ZDYHZJ
FROM #tempC8

--xt
SELECT 'OK' AS ReMesInfo
return 

END   
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].usp_jg_ScData_Tjf') AND OBJECTPROPERTY(id, N'IsProcedure') = 1)
	DROP PROCEDURE [dbo].usp_jg_ScData_Tjf
GO

CREATE PROCEDURE [dbo].[usp_jg_ScData_Tjf]  
    @PlanGUID VARCHAR(40) 
AS   
BEGIN    

IF @PlanGUID='' 
BEGIN
	RETURN 
END

DECLARE @ProjGUID AS varchar(40)	--һ����ĿGUID
DECLARE @ParentCode AS varchar(40)  --һ����ĿProjCode

--���۷�����һ����Ŀ
SELECT @ProjGUID=ProjGUID
FROM s_TjTjPlan 
WHERE TjPlanGUID=@PlanGUID

SELECT @ParentCode = ProjCode
FROM p_project
WHERE ProjGUID=@ProjGUID



--����ǰ����ɾ���������ⱨ��Դ��������Ŀ��ֵ������ҵ̬��ֵ������¥����ֵ����
--��¥����Ϣ����������������Ϣ�����������۸��쳣������������㷿����ϸ��
--���ɺ�ˢ��4��ҳǩ�������б�
DELETE s_DjTjResources
WHERE PlanGUID=@PlanGUID

DELETE s_DjTjProjValue
WHERE PlanGUID=@PlanGUID

DELETE s_DjTjYTValue
WHERE PlanGUID=@PlanGUID

DELETE s_DjTjBldValue
WHERE PlanGUID=@PlanGUID
--
DELETE s_DjTjBldAnalysis
WHERE PlanGUID=@PlanGUID


--SELECT *  
--FROM data_dict dd
--WHERE dd.table_name_c='�۸��쳣�����'

--SELECT * FROM myAction 
--WHERE ObjectType='01010109'

--�Ƿ���ģ��
IF EXISTS(SELECT 1 FROM s_TjTjResult WHERE TjPlanGUID=@PlanGUID)
BEGIN
	PRINT '�ѵ���۸�'

--���ɱ��α�����Դ���-C1�����ε���ķ��䷶Χ��
select pr.BldGUID,count(sdt.RoomGUID) as Ts
,sum(isnull((case when isnull(pr.ScBldArea,0)=0 then isnull(pr.YsBldArea,0) else isnull(pr.ScBldArea,0) end ),0)) as BldArea
,isnull((case when isnull(sum(isnull(pr.YsBldArea,0)),0)=0 then 0 else round( sum(isnull(pr.PlanTotal,0))*1.0/sum(pr.YsBldArea),4) end ),0) as TargetAmount
,isnull(sum(isnull(pr.PlanTotal,0)),0) as TargetTotle
,isnull([dbo].[fn_GetHtAllAmount](pr.BldGUID),0) as HTTotle
,isnull([dbo].[fn_GetHtAllAmount_AreaSum](pr.BldGUID),0) as HTTotleAreaSum
,sum(isnull((case when isnull(pr.ScBldArea,0)=0 then isnull(pr.YsBldArea,0) else isnull(pr.ScBldArea,0) end ),0)) as PrScYs_AreaSum
--,isnull(sum(isnull(pr.TotalDj,0)),0) as RecentlyTotle
,isnull(sum(ISNULL([dbo].[fn_GetRoomTjfAmountSum](sdt.RoomGUID),0)),0) as RecentlyTotle
,isnull(sum(isnull(sdt.TotalTj,0)),0) as BCRecentlyTotle
,[dbo].[fn_GetJZDateFromSaleBldGUID](pr.BldGUID) as JZDate
into #tempC1
from s_TjTjResult sdt left join p_room pr
on sdt.RoomGUID=pr.RoomGUID
left join p_Building pb
on pr.BldGUID=pb.BldGUID
WHERE TjPlanGUID=@PlanGUID
group by pr.BldGUID


insert into s_DjTjResources(DjTjResourcesGUID,PlanGUID,YTName,BldGUID,Ts
,BldArea,TargetAmount,TargetTotle,HTAmount,HTTotle,RecentlyAmount,RecentlyTotle,BCRecentlyAmount,BCRecentlyTotle,JZDate)
select dbo.SeqNewId() AS DjTjResourcesGUID,@PlanGUID,[dbo].[fn_GetYtNameFromBld](BldGUID,'') as YTName,BldGUID,Ts
,BldArea,TargetAmount,TargetTotle
,(case when HTTotleAreaSum=0 then 0 else round( HTTotle*1.0/HTTotleAreaSum,4) end) as HTAmount
,HTTotle
,(case when PrScYs_AreaSum=0 then 0 else round( RecentlyTotle*1.0/PrScYs_AreaSum,4) end) as RecentlyAmount
,RecentlyTotle
,(case when PrScYs_AreaSum=0 then 0 else round( BCRecentlyTotle*1.0/PrScYs_AreaSum,4) end) as BCRecentlyAmount
,BCRecentlyTotle
,(case when JZDate='' then NULL else JZDate end) as JZDate
from #tempC1

--------------[���뱾���޸�����:2014-09-11]-------------

--1.1----------------------------------------------------
--������Ŀ��ֵ(���)-C2
declare @TargetBJArea_Proj_Area as decimal(23,4)=0.0000
declare @TargetDTArea_Proj_Area as decimal(23,4)=0.0000
declare @TZQDT_Proj_Area as decimal(23,4)=0.0000
declare @YTYS_Proj_Area as decimal(23,4)=0.0000
declare @YTWS_Proj_Area as decimal(23,4)=0.0000
declare @BCBP_Proj_Area as decimal(23,4)=0.0000
declare @WTS_Proj_Area as decimal(23,4)=0.0000
declare @XJ_Proj_Area as decimal(23,4)=0.0000

--Ŀ�걨�����					
--TargetBJArea					
--��ǰһ����Ŀ������ĩ����Ŀ������¥������ҵ�ƻ����ys_BusinessPlan����
--��Ӧ�Ĺ���¥����KsArea�������
select @TargetBJArea_Proj_Area=isnull(sum(isnull(gcb.KsArea,0)),0)
FROM dbo.jd_GCBuilding gcb 
where gcb.ProjGUID in (
SELECT ProjGUID FROM p_project WHERE ParentCode=@ParentCode
)

--Ŀ�궯̬���
--TargetDTArea
--��ǰһ����Ŀ������δ���۵Ĺ���¥��ȡ����¥�����е�KsArea�������
--+һ����Ŀ������������¥�����з���Ԥ�������P_ROOM.YsBldArea��֮��
select @TargetDTArea_Proj_Area = isnull(sum(isnull(dbo.fn_CalcBldValue_Tjf(gcb.BldGUID,'targetdtarea',@PlanGUID),0)),0)
FROM dbo.jd_GCBuilding gcb 
where gcb.ProjGUID in (
SELECT ProjGUID FROM p_project WHERE ParentCode=@ParentCode
)



--����ǰ��ֵ̬
--TZQDT
--��ǰһ����Ŀ������δ����δ���۵Ĺ���¥��ȡ����¥�����е�KsArea�������
--+һ����Ŀ������������¥�����з������½������֮�ͣ���ʵ�������ȡʵ�������ScBldArea����ʵ��Ϊ0��ȡԤ�������													
select @TZQDT_Proj_Area = isnull(sum(isnull(dbo.fn_CalcBldValue_Tjf(gcb.BldGUID,'tzqdt',@PlanGUID),0)),0)
FROM dbo.jd_GCBuilding gcb 
where gcb.ProjGUID in (
SELECT ProjGUID FROM p_project WHERE ParentCode=@ParentCode
)

--��������					
--YTYS
--��ǰһ����Ŀ�������������۵ķ����ڷ�����ScBldArea�ϼƣ���ScBldAreaΪ0��ȡ�÷����YsBldArea													
select @YTYS_Proj_Area= isnull(sum(isnull(dbo.fn_CalcBldValue_Tjf(gcb.BldGUID,'ytys_area',@PlanGUID),0)),0)
FROM dbo.jd_GCBuilding gcb 
where gcb.ProjGUID in (
SELECT ProjGUID FROM p_project WHERE ParentCode=@ParentCode
)

--����δ��
--YTWS
--��ǰһ����Ŀ����¥���³����α������ ��������δ�۵ķ����ڷ�����ScBldArea�ϼƣ���ScBldAreaΪ0��ȡ�÷����YsBldArea
select @YTWS_Proj_Area=isnull(sum( case when isnull(ScBldArea,0)=0 then isnull(YsBldArea,0) else isnull(ScBldArea,0) end  ),0)
from p_room
where BldGUID in 
(

	select pb.BldGUID
	FROM p_Building pb 
	where pb.ProjGUID in (
	SELECT ProjGUID FROM p_project WHERE ParentCode=@ParentCode
	) 
	AND  --����¥��
	(
	Not EXISTS(SELECT 1 FROM p_room WHERE BldGUID=pb.BldGUID AND TotalDj=0)
	AND 
	EXISTS(SELECT 1 FROM p_room WHERE BldGUID=pb.BldGUID)
	)
	and pb.IsBld=1
)
and RoomGUID not in (select RoomGUID from s_TjTjResult where TjPlanGUID=@PlanGUID)
and NOT EXISTS(SELECT 1 FROM s_trade WHERE RoomGUID=p_room.RoomGUID AND TradeStatus='����')
AND Status NOT IN ('�Ϲ�','ǩԼ')

--���α���
--BCBP
--s_TjTjResult��ķ����ScBldArea�ϼƣ���ScBldAreaΪ0��ȡ�÷����YsBldArea													
select @BCBP_Proj_Area=isnull(sum( case when isnull(pr.ScBldArea,0)=0 then isnull(pr.YsBldArea,0) else isnull(pr.ScBldArea,0) end  ) ,0)
from s_TjTjResult sdt left join p_room pr
on sdt.RoomGUID=pr.RoomGUID
where sdt.TjPlanGUID=@PlanGUID



--δ����
--WTS
--��������[����δ����ļ���]
SELECT @WTS_Proj_Area=ISNULL(SUM(gcb.KsArea),0.00)
FROM dbo.jd_GCBuilding  gcb
--δ�����õ�¥��
WHERE gcb.BldFullCode NOT IN
(
	SELECT p_Building.ParentCode + '.' + p_Building.BldCode
	FROM dbo.p_Project
	INNER JOIN dbo.p_Building ON dbo.p_Building.ProjGUID = dbo.p_Project.ProjGUID
	WHERE p_Project.ParentCode=@ParentCode	--һ����Ŀ������Ŀcode
)
AND gcb.ProjGUID IN
(
	SELECT ProjGUID FROM dbo.p_Project WHERE ParentCode=@ParentCode
)
SELECT @WTS_Proj_Area=@WTS_Proj_Area+ISNULL(SUM(gcb.KsArea),0.00)
FROM dbo.jd_GCBuilding  gcb
--�����õ�¥��,�޷���
WHERE gcb.BldFullCode IN 
(
	SELECT pbld.ParentCode + '.' + pbld.BldCode
	FROM dbo.p_Project proj
	LEFT join dbo.jd_GCBuilding gcb ON gcb.ProjGUID=proj.ProjGUID
	LEFT JOIN dbo.p_Building pbld ON pbld.ParentCode + '.' + pbld.BldCode = gcb.BldFullCode
	LEFT JOIN dbo.p_Room ON dbo.p_Room.BldGUID = pbld.BldGUID
	WHERE proj.ParentCode=@ParentCode AND pbld.BldGUID IS NOT NULL AND p_Room.RoomGUID IS NULL
)
AND gcb.ProjGUID IN
(
	SELECT ProjGUID FROM dbo.p_Project WHERE ParentCode=@ParentCode
)
SELECT @WTS_Proj_Area=@WTS_Proj_Area+ISNULL(SUM(gcb.KsArea),0.00)
FROM dbo.jd_GCBuilding  gcb
--�����ã��з��䣬���ǵ��ܼ�֮��0
WHERE gcb.BldFullCode IN 
(
	SELECT pbld.ParentCode + '.' + pbld.BldCode
	FROM dbo.p_Project proj
	LEFT join dbo.jd_GCBuilding gcb ON gcb.ProjGUID=proj.ProjGUID
	LEFT JOIN dbo.p_Building pbld ON pbld.ParentCode + '.' + pbld.BldCode = gcb.BldFullCode
	LEFT JOIN dbo.p_Room ON dbo.p_Room.BldGUID = pbld.BldGUID
	WHERE proj.ParentCode=@ParentCode AND pbld.BldGUID IS NOT NULL AND p_Room.RoomGUID IS NOT NULL AND p_Room.TotalDj=0
)
AND gcb.ProjGUID IN
(
	SELECT ProjGUID FROM dbo.p_Project WHERE ParentCode=@ParentCode
)
AND gcb.BldFullCode NOT IN
(
	--����ȡ���α����ķ���
	SELECT pbld.ParentCode + '.' + pbld.BldCode
	FROM dbo.s_TjTjResult
	INNER join p_Room pr ON pr.RoomGUID=dbo.s_TjTjResult.RoomGUID
	INNER JOIN dbo.p_Building pbld ON pbld.BldGUID = pr.BldGUID
)
--End Of �������

--С��
--XJ
--��������+����δ��+���α���+δ����
set @XJ_Proj_Area = @YTYS_Proj_Area+@YTWS_Proj_Area+@BCBP_Proj_Area+@WTS_Proj_Area


insert into s_DjTjProjValue(DjTjProjValueGUID,PlanGUID
,TargetBJArea,TargetDTArea
,TZQDT,YTYS,YTWS,BCBP,WTS,XJ
,Sort,ProjGUID)
select dbo.SeqNewId() as DjTjProjValueGUID,@PlanGUID
,@TargetBJArea_Proj_Area,@TargetDTArea_Proj_Area
,@TZQDT_Proj_Area,@YTYS_Proj_Area,@YTWS_Proj_Area,@BCBP_Proj_Area,@WTS_Proj_Area,@XJ_Proj_Area
,1,@ProjGUID



-----------���ϴ���,���ʱ��:2014��9��11��20:11:23
--1.2----------------------------------------------------
--������Ŀ��ֵ(���)-C2
declare @TargetBJArea_Proj_Hz as decimal(23,4)=0.0000
declare @TargetDTArea_Proj_Hz as decimal(23,4)=0.0000
declare @TZQDT_Proj_Hz as decimal(23,4)=0.0000
declare @YTYS_Proj_Hz as decimal(23,4)=0.0000
declare @YTWS_Proj_Hz as decimal(23,4)=0.0000
declare @BCBP_Proj_Hz as decimal(23,4)=0.0000
declare @WTS_Proj_Hz as decimal(23,4)=0.0000
declare @XJ_Proj_Hz as decimal(23,4)=0.0000

--Ŀ�걨�����					
--TargetBJArea					
--��ǰһ����Ŀ������ĩ����Ŀ������¥������ҵ�ƻ����ys_BusinessPlan����
--��Ӧ�����°汾��ÿ��Ԥ��¥���Ļ�׼Ŀ���ܼۣ�ys_BusinessPlanDtl.TotalAmount���ϼ�
select @TargetBJArea_Proj_Area=isnull(sum(isnull(gcb.YSMBTotle,0)),0)
FROM dbo.jd_GCBuilding gcb 
where gcb.ProjGUID in (
SELECT ProjGUID FROM p_project WHERE ParentCode=@ParentCode
)

--Ŀ�궯̬���
--TargetDTArea
--��ǰһ����Ŀ������δ���۵�ȡ��ҵ�ƻ��������°汾����¥���Ļ�׼Ŀ���ܼ�֮��
--+������¥�������з������ҵ�ƻ��ֻ��ܼ�p_room.PlanTotal֮��

select @TargetDTArea_Proj_Area = isnull(sum(isnull(dbo.fn_CalcBldValue_Tjf(gcb.BldGUID,'targetdtarea_hz',@PlanGUID),0)),0)
FROM dbo.jd_GCBuilding gcb 
where gcb.ProjGUID in (
SELECT ProjGUID FROM p_project WHERE ParentCode=@ParentCode
)


--����ǰ��ֵ̬
--TZQDT
--��ǰһ����Ŀ�������������۷����ܼۺϼ�
--+��������δ�۷����ܼۺϼ�
--+δ���۵Ĺ���¥��YSMBTotle
select @TZQDT_Proj_Hz = ISNULL(sum(isnull(YTYS,0)),0)
from p_room pr left join vs_YTYS_View vsYTYS
on pr.RoomGUID=vsYTYS.RoomGUID
where BldGUID in 
(
	select BldGUID
	FROM p_Building pb 
	where pb.ProjGUID in (
	SELECT ProjGUID FROM p_project WHERE ParentCode=@ParentCode
	) 
	AND --����¥��
	(
	Not EXISTS(SELECT 1 FROM p_room WHERE BldGUID=pb.BldGUID AND TotalDj=0)
	AND 
	EXISTS(SELECT 1 FROM p_room WHERE BldGUID=pb.BldGUID)
	)
	and pb.IsBld=1
)
AND EXISTS(SELECT 1 FROM s_trade WHERE RoomGUID=pr.RoomGUID AND TradeStatus='����')
AND pr.Status IN ('�Ϲ�','ǩԼ')

select @TZQDT_Proj_Hz = @TZQDT_Proj_Hz + isnull(sum(ISNULL([dbo].[fn_GetRoomYTWS](pr.RoomGUID),0)),0)
from p_room pr 
where BldGUID in 
(
	select BldGUID
	FROM p_Building pb 
	where pb.ProjGUID in (
	SELECT ProjGUID FROM p_project WHERE ParentCode=@ParentCode
	) 
	AND --����¥��
	(
	Not EXISTS(SELECT 1 FROM p_room WHERE BldGUID=pb.BldGUID AND TotalDj=0)
	AND 
	EXISTS(SELECT 1 FROM p_room WHERE BldGUID=pb.BldGUID)
	)
	and pb.IsBld=1
)
AND NOT EXISTS(SELECT 1 FROM s_trade WHERE RoomGUID=pr.RoomGUID AND TradeStatus='����')
AND pr.Status NOT IN ('�Ϲ�','ǩԼ')

select @TZQDT_Proj_Hz = @TZQDT_Proj_Hz + isnull(sum(ISNULL([dbo].[fn_CalcBldValue_Tjf](gcb.BldGUID,'tzqdt_hz',@PlanGUID),0)),0)
FROM dbo.jd_GCBuilding gcb 
where gcb.ProjGUID in (
SELECT ProjGUID FROM p_project WHERE ParentCode=@ParentCode
)



--��������					
--YTYS
--��ǰһ����Ŀ�������������۷����ܼۺϼ�
select @YTYS_Proj_Hz = ISNULL(sum(isnull(YTYS,0)),0)
from p_room pr left join vs_YTYS_View vsYTYS
on pr.RoomGUID=vsYTYS.RoomGUID
where BldGUID in 
(
	select BldGUID
	FROM p_Building pb 
	where pb.ProjGUID in (
	SELECT ProjGUID FROM p_project WHERE ParentCode=@ParentCode
	) 
	AND --����¥��
	(
	Not EXISTS(SELECT 1 FROM p_room WHERE BldGUID=pb.BldGUID AND TotalDj=0)
	AND 
	EXISTS(SELECT 1 FROM p_room WHERE BldGUID=pb.BldGUID)
	)
	and pb.IsBld=1
)
AND EXISTS(SELECT 1 FROM s_trade WHERE RoomGUID=pr.RoomGUID AND TradeStatus='����')
AND pr.Status IN ('�Ϲ�','ǩԼ')

--����δ��
--YTWS
--��ǰһ����Ŀ�³����α������������������δ�۷���ĵ׼��ܼۺϼ�
select @YTWS_Proj_Hz=isnull(sum(ISNULL([dbo].[fn_GetRoomYTWS](RoomGUID),0)),0)
from p_room
where BldGUID in 
(

	select pb.BldGUID
	FROM p_Building pb 
	where pb.ProjGUID in (
	SELECT ProjGUID FROM p_project WHERE ParentCode=@ParentCode
	) 
	and	--����¥��
	(
	Not EXISTS(SELECT 1 FROM p_room WHERE BldGUID=pb.BldGUID AND TotalDj=0)
	AND 
	EXISTS(SELECT 1 FROM p_room WHERE BldGUID=pb.BldGUID)
	)
	and pb.IsBld=1
)
and RoomGUID not in (select RoomGUID from s_TjTjResult where TjPlanGUID=@PlanGUID)
and NOT EXISTS(SELECT 1 FROM s_trade WHERE RoomGUID=p_room.RoomGUID AND TradeStatus='����')
AND Status NOT IN ('�Ϲ�','ǩԼ')

--���α���
--BCBP
--s_TjTjResult��ķ���ĵ׼��ܼ�TotalDj�ϼ�												
select @BCBP_Proj_Hz=isnull(sum( isnull(sdt.TotalDj,0)) ,0)
from s_TjTjResult sdt 
where sdt.TjPlanGUID=@PlanGUID

--δ����
--WTS
--��������[����δ����ļ���]
SELECT @WTS_Proj_Hz=ISNULL(SUM(gcb.YSMBTotle),0.00)
FROM dbo.jd_GCBuilding  gcb
--δ�����õ�¥��
WHERE gcb.BldFullCode NOT IN
(
	SELECT p_Building.ParentCode + '.' + p_Building.BldCode
	FROM dbo.p_Project
	INNER JOIN dbo.p_Building ON dbo.p_Building.ProjGUID = dbo.p_Project.ProjGUID
	WHERE p_Project.ParentCode=@ParentCode	--һ����Ŀ������Ŀcode
)
AND gcb.ProjGUID IN
(
	SELECT ProjGUID FROM dbo.p_Project WHERE ParentCode=@ParentCode
)
SELECT @WTS_Proj_Hz=@WTS_Proj_Hz+ISNULL(SUM(gcb.YSMBTotle),0.00)
FROM dbo.jd_GCBuilding  gcb
--�����õ�¥��,�޷���
WHERE gcb.BldFullCode IN 
(
	SELECT pbld.ParentCode + '.' + pbld.BldCode
	FROM dbo.p_Project proj
	LEFT join dbo.jd_GCBuilding gcb ON gcb.ProjGUID=proj.ProjGUID
	LEFT JOIN dbo.p_Building pbld ON pbld.ParentCode + '.' + pbld.BldCode = gcb.BldFullCode
	LEFT JOIN dbo.p_Room ON dbo.p_Room.BldGUID = pbld.BldGUID
	WHERE proj.ParentCode=@ParentCode AND pbld.BldGUID IS NOT NULL AND p_Room.RoomGUID IS NULL
)
AND gcb.ProjGUID IN
(
	SELECT ProjGUID FROM dbo.p_Project WHERE ParentCode=@ParentCode
)
SELECT @WTS_Proj_Hz=@WTS_Proj_Hz+ISNULL(SUM(gcb.YSMBTotle),0.00)
FROM dbo.jd_GCBuilding  gcb
--�����ã��з��䣬���ǵ��ܼ�֮��0
WHERE gcb.BldFullCode IN 
(
	SELECT pbld.ParentCode + '.' + pbld.BldCode
	FROM dbo.p_Project proj
	LEFT join dbo.jd_GCBuilding gcb ON gcb.ProjGUID=proj.ProjGUID
	LEFT JOIN dbo.p_Building pbld ON pbld.ParentCode + '.' + pbld.BldCode = gcb.BldFullCode
	LEFT JOIN dbo.p_Room ON dbo.p_Room.BldGUID = pbld.BldGUID
	WHERE proj.ParentCode=@ParentCode AND pbld.BldGUID IS NOT NULL AND p_Room.RoomGUID IS NOT NULL AND p_Room.TotalDj=0
)
AND gcb.ProjGUID IN
(
	SELECT ProjGUID FROM dbo.p_Project WHERE ParentCode=@ParentCode
)
AND gcb.BldFullCode NOT IN
(
	--����ȡ���α����ķ���
	SELECT pbld.ParentCode + '.' + pbld.BldCode
	FROM dbo.s_TjTjResult
	INNER join p_Room pr ON pr.RoomGUID=dbo.s_TjTjResult.RoomGUID
	INNER JOIN dbo.p_Building pbld ON pbld.BldGUID = pr.BldGUID
)
--End Of �������

--С��
--XJ
--��������+����δ��+���α���+δ����
set @XJ_Proj_Hz = @YTYS_Proj_Hz+@YTWS_Proj_Hz+@BCBP_Proj_Hz+@WTS_Proj_Hz

insert into s_DjTjProjValue(DjTjProjValueGUID,PlanGUID
,TargetBJArea,TargetDTArea
,TZQDT,YTYS,YTWS,BCBP,WTS,XJ
,Sort,ProjGUID)
select dbo.SeqNewId() as DjTjProjValueGUID,@PlanGUID
,@TargetBJArea_Proj_Hz,@TargetDTArea_Proj_Hz
,@TZQDT_Proj_Hz,@YTYS_Proj_Hz,@YTWS_Proj_Hz,@BCBP_Proj_Hz,@WTS_Proj_Hz,@XJ_Proj_Hz
,2,@ProjGUID



---------���ϣ���ɣ�2014��9��11��20:48:26
--1.3.1---------------------------------------------------
--����¥����ֵ�������-C3

--TargetBJArea
--����¥������ҵ�ƻ����ys_BusinessPlan���ж�Ӧ�����°汾��Ԥ��¥���Ľ��������ys_BusinessPlanDtl.BldArea��
--TargetDTArea
--¥��δ����ȡ��ҵ�ƻ��������°汾��¥���������,¥��������ȡ¥�������з���Ԥ�����֮��p_room.YsBldArea
--TZQDT
--¥��δ����ȡ��ҵ�ƻ��������°汾��¥���������
--¥��������ȡ¥�������з���ʵ�����p_room.ScBldArea֮�ͣ�ʵ�����Ϊ0ȡ�����Ԥ�������
--YTYS
--¥���������������۵ķ����ڷ�����ScBldArea�ϼƣ���ScBldAreaΪ0��ȡ�÷����YsBldArea
--YTWS
--¥���³����α��������������δ�۵ķ����ڷ�����ScBldArea�ϼƣ���ScBldAreaΪ0��ȡ�÷����YsBldArea

--BCBP
--s_TjTjResult��ķ����ScBldArea�ϼƣ���ScBldAreaΪ0��ȡ�÷����YsBldArea
--WTS
--¥��δ�����Ҳ��ڱ��α����ڣ�ȡ��ҵ�ƻ��������°汾��¥���������(���ȷ�Ͼ���0)
--¥��������ȡ0
--XJ
--��������+����δ��+���α���+δ����

select 
gcb.BldGUID,gcb.ProductGUID
,isnull(gcb.KsArea,0) as TargetBJArea
,isnull(dbo.fn_CalcBldValue_Tjf(gcb.BldGUID,'targetdtarea',@PlanGUID),0) as TargetDTArea
,isnull(dbo.fn_CalcBldValue_Tjf(gcb.BldGUID,'tzqdt',@PlanGUID),0) as TZQDT
,isnull(dbo.fn_CalcBldValue_Tjf(gcb.BldGUID,'ytys_area',@PlanGUID),0) as YTYS
,isnull(dbo.fn_CalcBldValue_Tjf(gcb.BldGUID,'ytws_area',@PlanGUID),0) as YTWS
,isnull(dbo.fn_CalcBldValue_Tjf(gcb.BldGUID,'bcbp_area_any',@PlanGUID),0) as BCBP
,(case when [dbo].[fn_IsWTsBldAndNoBcPlan_Tjf](gcb.BldGUID,@PlanGUID)=1 then CONVERT(MONEY,1) else 0 end ) as WTS
,cast(0 as decimal(23,4)) as XJ
,dbo.[fn_GetYtNameFromBld](gcb.BldGUID,'gcbuilding') as YTName
into #tempC3_Area
FROM dbo.jd_GCBuilding gcb
where gcb.ProjGUID in (
SELECT ProjGUID FROM p_project WHERE ParentCode=@ParentCode
)


--******sunsoft area************
--��WTS��ֵ�����ݹ���¥������������¥��
	UPDATE #tempC3_Area
	SET WTS=source.KsArea
	FROM
	(
		SELECT ISNULL(gcb.KsArea,0.00) KsArea , gcb.BldGUID
		FROM 
		dbo.jd_GCBuilding gcb
	) source
	WHERE source.BldGUID=#tempC3_Area.BldGUID AND #tempC3_Area.WTS=1
--******************

update #tempC3_Area
set XJ=(YTYS+YTWS+BCBP+WTS)




insert into s_DjTjBldValue(DjTjBldValueGUID,PlanGUID,TargetBJArea,TargetDTArea,TZQDT
,YTYS,YTWS,BCBP,WTS,XJ
,BldGUID,YTGUID,Sort,ProjGUID)
select dbo.SeqNewId() as DjTjBldValueGUID,@PlanGUID,TargetBJArea,TargetDTArea,TZQDT
,YTYS,YTWS,BCBP,WTS
,(YTYS+YTWS+BCBP+WTS) as XJ
,BldGUID
,ProductGUID as YTGUID, 1 as Sort,@ProjGUID
from #tempC3_Area



--1.3.3---------------------------------------------------
--����¥����ֵ����ֵ��-C3
--TargetBJArea
--����¥������ҵ�ƻ����ys_BusinessPlan���ж�Ӧ�����°汾��Ԥ��¥���Ļ�׼Ŀ���ܼۣ�ys_BusinessPlanDtl.TotalAmount��
--TargetDTArea
--¥��δ����ȡ��ҵ�ƻ��������°汾��¥����׼Ŀ���ܼ�
--¥��������ȡ¥�������з�����ҵ�ƻ��ܼ�p_room.PlanTotal
--TZQDT
--¥��δ����ȡ��ҵ�ƻ��������°汾��¥����׼Ŀ���ܼ�
--¥��������ȡ¥���������������۵ķ����ܼۺϼ�+����δ�۵ķ����ܼۺϼ�
--YTYS
--¥���������������۵ķ����ܼۺϼ�
--YTWS
--¥���³����α��������������δ�۵ķ����ܼۺϼ�

--BCBP
--s_TjTjResult��ķ���ĵ׼��ܼ�TotalDj�ϼ�
--WTS
--¥��δ�����Ҳ��ڱ��α����ڣ�ȡ��ҵ�ƻ��������°汾��¥����׼Ŀ���ܼ�(���ȷ�Ͼ���0)
--¥��������ȡ0
--XJ
--��������+����δ��+���α���+δ����

select 
gcb.BldGUID,gcb.ProductGUID
,isnull(gcb.YSMBTotle,0) as TargetBJArea
,isnull(dbo.fn_CalcBldValue_Tjf(gcb.BldGUID,'targetdtarea_hz',@PlanGUID),0) as TargetDTArea
,isnull(dbo.fn_CalcBldValue_Tjf(gcb.BldGUID,'tzqdt_hz_special',@PlanGUID),0) as TZQDT

,isnull(dbo.fn_CalcBldValue_Tjf(gcb.BldGUID,'ytys_hz',@PlanGUID),0) as YTYS
,isnull(dbo.fn_CalcBldValue_Tjf(gcb.BldGUID,'ytws_hz',@PlanGUID),0) as YTWS

,isnull(dbo.fn_CalcBldValue_Tjf(gcb.BldGUID,'bcbp_hz_any',@PlanGUID),0) as BCBP
,(case when [dbo].[fn_IsWTsBldAndNoBcPlan_Tjf](gcb.BldGUID,@PlanGUID)=1 then CONVERT(MONEY,1) else 0 end ) as WTS
,cast(0 as decimal(23,4)) as XJ
,dbo.[fn_GetYtNameFromBld](gcb.BldGUID,'gcbuilding') as YTName  --��������p_BuildProductType��level=2��
into #tempC3_Hz
FROM dbo.jd_GCBuilding gcb
where gcb.ProjGUID in (
SELECT ProjGUID FROM p_project WHERE ParentCode=@ParentCode
)


--******sunsoft area************
--��WTS��ֵ�����ݹ���¥������������¥��
	UPDATE #tempC3_Hz
	SET #tempC3_Hz.WTS=source.YSMBTotle
	FROM
	(
		SELECT ISNULL(gcb.YSMBTotle,0.00) YSMBTotle , gcb.BldGUID
		FROM 
		dbo.jd_GCBuilding gcb
	) source
	WHERE source.BldGUID=#tempC3_Hz.BldGUID AND #tempC3_Hz.WTS=1
--******************


update #tempC3_Hz
set XJ=(YTYS+YTWS+BCBP+WTS)


insert into s_DjTjBldValue(DjTjBldValueGUID,PlanGUID,TargetBJArea,TargetDTArea,TZQDT
,YTYS,YTWS,BCBP,WTS,XJ
,BldGUID,YTGUID,Sort,ProjGUID)
select dbo.SeqNewId() as DjTjBldValueGUID,@PlanGUID,TargetBJArea,TargetDTArea,TZQDT
,YTYS,YTWS,BCBP,WTS
,(YTYS+YTWS+BCBP+WTS) as XJ
,BldGUID
,ProductGUID as YTGUID, 3 as Sort,@ProjGUID
from #tempC3_Hz

--1.3.2---------------------------------------------------
--����¥����ֵ�����ۣ�-C3

--¥���Ļ�ֵ/���
insert into s_DjTjBldValue(DjTjBldValueGUID,PlanGUID,TargetBJArea,TargetDTArea,TZQDT
,YTYS,YTWS,BCBP,WTS,XJ
,BldGUID,YTGUID,Sort,ProjGUID)
select dbo.SeqNewId() as DjTjBldValueGUID,@PlanGUID
,(case when b.TargetBJArea=0 then 0 else round( a.TargetBJArea*1.0/b.TargetBJArea,4) end) as TargetBJArea
,(case when b.TargetDTArea=0 then 0 else round( a.TargetDTArea*1.0/b.TargetDTArea,4) end) as TargetDTArea
,(case when b.TZQDT=0 then 0 else round( a.TZQDT*1.0/b.TZQDT,4) end) as TZQDT
,(case when b.YTYS=0 then 0 else round( a.YTYS*1.0/b.YTYS,4) end) as YTYS
,(case when b.YTWS=0 then 0 else round( a.YTWS*1.0/b.YTWS,4) end) as YTWS
,(case when b.BCBP=0 then 0 else round( a.BCBP*1.0/b.BCBP,4) end) as BCBP
,(case when b.WTS=0 then 0 else round( a.WTS*1.0/b.WTS,4) end) as WTS
,(case when b.XJ=0 then 0 else round( a.XJ*1.0/b.XJ,4) end) as XJ
,a.BldGUID
,(case when a.ProductGUID is null then b.ProductGUID else a.ProductGUID end) as YTGUID
, 2 as Sort
,@ProjGUID
from #tempC3_Hz a left join #tempC3_Area b
on a.BldGUID=b.BldGUID

--1.4.1---------------------------------------------------
--����ҵ̬��ֵ�������-C4
--����һ����Ŀ�ĸ�ҵ̬������¥���Ķ�Ӧָ��ϼ�

--ҵ̬(cb_HkbProductWork.ProductGUID)���� ��Ʒ����(cb_HkbProductWork.ProductName,cb_HkbProductWork.BProductTypeCode)��
--���Զ��ҵ̬���Թ���ͬһ����Ʒ������

select 
( SELECT top 1 BuildProductTypeGUID FROM p_BuildProductType WHERE LEVEL=2 and BProductTypeShortName=#tempC3_Area.YTName ) as YTGUID  --level2�²����ظ�
,sum(round(isnull(TargetBJArea,0),4)) as TargetBJArea
,sum(round(isnull(TargetDTArea,0),4)) as TargetDTArea
,sum(round(isnull(TZQDT,0),4)) as TZQDT
,sum(round(isnull(YTYS,0),4)) as YTYS
,sum(round(isnull(YTWS,0),4)) as YTWS
,sum(round(isnull(BCBP,0),4)) as BCBP
,sum(round(isnull(WTS,0),4)) as WTS
,sum(round(isnull(XJ,0),4)) as XJ
into #tempC3_Area_Yt
from #tempC3_Area
--group by ProductGUID
group by YTName

insert into s_DjTjYTValue(DjTjYTValueGUID,PlanGUID
,TargetBJArea
,TargetDTArea
,TZQDT,YTYS,YTWS,BCBP,WTS,XJ
,YTGUID,Sort,ProjGUID)
select dbo.SeqNewId() as DjTjYTValueGUID,@PlanGUID as PlanGUID
,TargetBJArea
,TargetDTArea
,TZQDT,YTYS,YTWS,BCBP,WTS,XJ
,YTGUID
,1 as Sort
,@ProjGUID as ProjGUID 
from #tempC3_Area_Yt



--select * from #tempC3_Hz
--order by bldguid
--1.4.2---------------------------------------------------
--����ҵ̬��ֵ����ֵ��-C4
--����һ����Ŀ�ĸ�ҵ̬������¥���Ķ�Ӧָ��ϼ�
select 
--ProductGUID as YTGUID
( SELECT top 1 BuildProductTypeGUID FROM p_BuildProductType WHERE LEVEL=2 and BProductTypeShortName=#tempC3_Hz.YTName ) as YTGUID  --level2�²����ظ�
,sum(round(isnull(TargetBJArea,0),4)) as TargetBJArea
,sum(round(isnull(TargetDTArea,0),4)) as TargetDTArea
,sum(round(isnull(TZQDT,0),4)) as TZQDT
,sum(round(isnull(YTYS,0),4)) as YTYS
,sum(round(isnull(YTWS,0),4)) as YTWS
,sum(round(isnull(BCBP,0),4)) as BCBP
,sum(round(isnull(WTS,0),4)) as WTS
,sum(round(isnull(XJ,0),4)) as XJ
into #tempC3_Hz_Yt
from #tempC3_Hz
--group by ProductGUID
group by YTName


insert into s_DjTjYTValue(DjTjYTValueGUID,PlanGUID
,TargetBJArea
,TargetDTArea
,TZQDT,YTYS,YTWS,BCBP,WTS,XJ
,YTGUID,Sort,ProjGUID)
select dbo.SeqNewId() as DjTjYTValueGUID,@PlanGUID as PlanGUID
,TargetBJArea
,TargetDTArea
,TZQDT,YTYS,YTWS,BCBP,WTS,XJ
,YTGUID
,3 as Sort
,@ProjGUID as ProjGUID 
from #tempC3_Hz_Yt

--select * from #tempC3_Hz_Yt
--order by YTGUID
--select * from #tempC3_Area_Yt
--order by YTGUID
--1.4.3---------------------------------------------------
--����ҵ̬��ֵ�����ۣ�-C4
--ҵ̬�Ļ�ֵ/���
insert into s_DjTjYTValue(DjTjYTValueGUID,PlanGUID
,TargetBJArea
,TargetDTArea
,TZQDT,YTYS,YTWS,BCBP,WTS,XJ
,YTGUID,Sort,ProjGUID)
select dbo.SeqNewId() as DjTjBldValueGUID,@PlanGUID
,round((case when b.TargetBJArea=0 then 0 else a.TargetBJArea*1.0/b.TargetBJArea end),4) as TargetBJArea
,round((case when b.TargetDTArea=0 then 0 else a.TargetDTArea*1.0/b.TargetDTArea end),4) as TargetDTArea
,round((case when b.TZQDT=0 then 0 else a.TZQDT*1.0/b.TZQDT end),4) as TZQDT
,round((case when b.YTYS=0 then 0 else a.YTYS*1.0/b.YTYS end),4) as YTYS
,round((case when b.YTWS=0 then 0 else a.YTWS*1.0/b.YTWS end),4) as YTWS
,round((case when b.BCBP=0 then 0 else a.BCBP*1.0/b.BCBP end),4) as BCBP
,round((case when b.WTS=0 then 0 else a.WTS*1.0/b.WTS end),4) as WTS
,round((case when b.XJ=0 then 0 else a.XJ*1.0/b.XJ end),4) as XJ
,(case when a.YTGUID is null then b.YTGUID else a.YTGUID end) as YTGUID
, 2 as Sort
,@ProjGUID
from #tempC3_Hz_Yt a left join #tempC3_Area_Yt b
on a.YTGUID=b.YTGUID



--1.4.3---------------------------------------------------
--����¥����Ϣ����-C5
--Ts:��¥��ά�Ȼ���s_TjTjResult����ÿ��¥���±����ϱ��ķ�������
--BldArea:��¥��ά�Ȼ���s_TjTjResult����ÿ��¥���±����ϱ��ķ����ڷ�����ʵ�⽨�����p_room.ScBldArea��ʵ��Ϊ0ȡԤ�۽������YsBldArea��
--ZTs:��¥��ά�Ȼ���ÿ��¥����������
--ZBldArea:��¥��ά�Ȼ���ÿ��¥�������з����ڷ�����Ԥ�۽������p_room.YsBldArea
--BuAmount:ȡ��ҵ�ƻ��������°汾��¥����׼Ŀ�굥��ys_BusinessPlanDtl.Amount
--BuTotle:ȡ��ҵ�ƻ��������°汾��¥����׼Ŀ���ܼ�ys_BusinessPlanDtl.TotalAmount
--FHAmount:ȡ¥���б����ϱ��ķ�Դ����ҵ�ƻ��ֻ��ܼ�֮��s_TjTjResult.TotalBu/��Ӧ�����Ԥ�����p_room.Ysbldarea֮��
--FHTotle:ȡ¥���б����ϱ��ķ�Դ����ҵ�ƻ��ֻ��ܼ�s_TjTjResult.TotalBu�ϼ�
--HTAmount:¥���������������۵ķ����ܼۺϼ�/�����ʵ�⽨������ϼ�p_room.ScBldArea��ʵ�����Ϊ0ȡԤ�۽��������
--HTTotle:¥���������������۵ķ����ܼۺϼ�
--RecentlyAmount:ȡ¥�������з����ڷ����ĵ׼��ܼ�p_room.TotleDj�ϼƣ����������Ч�ؼ�ʱ��ǰϵͳʱ�����ؼ���Ч��ʧЧ���ڼ䣬ȡTotalTj��
--/��Ӧ����ʵ�⽨�����p_room.ScBldArea֮�ͣ�ʵ��Ϊ0ȡԤ�ۣ�
--RecentlyTotle:ȡ¥�������з����ڷ����ĵ׼��ܼ�p_room.TotleDj�ϼƣ����������Ч�ؼ�ʱ��ǰϵͳʱ�����ؼ���Ч��ʧЧ���ڼ䣬ȡTotalTj��
--BCRecentlyAmount:ȡ¥���У�����δ�ϱ��ķ����ڷ����׼��ܼ�p_room.TotleDj�ϼ�+���ε���������s_TjTjResult�׼��ܼ�TotleDj�ϼƣ�
--/��Ӧ����ʵ�⽨�����p_room.ScBldArea֮�ͣ���ʵ��ȡԤ�ۣ�
--BCRecentlyTotle:ȡ¥���б���δ�ϱ��ķ����ڷ����׼��ܼ�+���ε���������s_TjTjResult�׼��ܼ�

insert into s_DjTjBldAnalysis(DjTjBldAnalysisGUID,PlanGUID
,YTName,BldGUID
,Ts,BldArea,ZTs,ZBldArea,BuAmount,BuTotle
,FHAmount,FHTotle,HTAmount,HTTotle
,RecentlyAmount,RecentlyTotle,BCRecentlyAmount,BCRecentlyTotle)
--/*
select dbo.SeqNewId() as DjTjBldAnalysisGUID,@PlanGUID
,a.YTName,a.BldGUID
,a.Ts
,a.BldArea
,b.ZTs
,b.ZBldArea
,a.BuAmount
,a.BuTotle
,a.FHAmount
,a.FHTotle
--HTAmount:¥���������������۵ķ����ܼۺϼ�/�����ʵ�⽨������ϼ�p_room.ScBldArea��ʵ�����Ϊ0ȡԤ�۽��������
,(case when isnull(b.HTTotleAreaSum,0)=0 then 0 else round( isnull(b.HTTotle,0)*1.0/b.HTTotleAreaSum,4) end) as HTAmount
,b.HTTotle
,(case when isnull(b.ScYsBldArea,0)=0 then 0 else round( isnull(b.RecentlyTotle,0)*1.0/b.ScYsBldArea,4) end) as RecentlyAmount
,b.RecentlyTotle
--BCRecentlyAmount:ȡ¥���У�����δ�ϱ��ķ����ڷ����׼��ܼ�(���ؼ۷��߼�ȡ��)�ϼ�+���ε���������s_TjTjResult�׼��ܼ�TotleDj�ϼƣ�
--/��Ӧ����ʵ�⽨�����p_room.ScBldArea֮�ͣ���ʵ��ȡԤ�ۣ�
,(case when isnull(b.ScYsBldArea,0)=0 then 0 else round( (isnull(c.BCRecentlyTotle_WSB,0)+isnull(a.BCRecentlyTotle_BCTZ,0))*1.0/b.ScYsBldArea,4) end) as BCRecentlyAmount
--BCRecentlyTotle:ȡ¥���б���δ�ϱ��ķ����ڷ����׼��ܼ�+���ε���������s_TjTjResult�׼��ܼ�
,(isnull(c.BCRecentlyTotle_WSB,0)+isnull(a.BCRecentlyTotle_BCTZ,0)) as BCRecentlyTotle
--,isnull(c.BCRecentlyTotle_WSB,0),isnull(a.BCRecentlyTotle_BCTZ,0)
from 
(
--¥���±����ϱ�����
select dbo.[fn_GetYtNameFromBld](pr.BldGUID,'') as YTName,pr.BldGUID
,count(sdt.RoomGUID) as Ts
,isnull(sum( case when isnull(pr.ScBldArea,0)=0 then isnull(pr.YsBldArea,0) else isnull(pr.ScBldArea,0) end  ) ,0) as BldArea
,isnull([dbo].[fn_getSlxtBldPrice](pr.BldGUID,'Amount'),0) as BuAmount
,isnull([dbo].[fn_getSlxtBldPrice](pr.BldGUID,'TotalAmount'),0) as BuTotle
,(case when isnull(sum(isnull(pr.YsBldArea,0)),0)=0 then 0 else round( isnull(sum(isnull(pr.PlanTotal,0)),0)*1.0/isnull(sum(isnull(pr.YsBldArea,0)),0),4) end) as FHAmount
,isnull(sum(isnull(pr.PlanTotal,0)),0) as FHTotle
,isnull(sum( isnull(sdt.TotalTj,0) ) ,0) as BCRecentlyTotle_BCTZ
from s_TjTjResult sdt left join p_room pr
on sdt.RoomGUID=pr.RoomGUID
left join p_Building pb
on pr.BldGUID=pb.BldGUID
where sdt.TjPlanGUID=@PlanGUID
group by pr.BldGUID  
) a
left join (
--¥�������з���
select pr.BldGUID
,count(1) as ZTs
,isnull(sum(isnull(pr.YsBldArea,0)),0) as ZBldArea
,isnull(sum(isnull([dbo].[fn_GetRoomTjfAmountSum](pr.RoomGUID),0)),0) as RecentlyTotle
,isnull(sum( case when isnull(pr.ScBldArea,0)=0 then isnull(pr.YsBldArea,0) else isnull(pr.ScBldArea,0) end  ) ,0) as ScYsBldArea
--HTTotle:¥���������������۵ķ����ܼۺϼ�
,ISNULL(sum(isnull(vsYTYS.YTYS,0)),0) as HTTotle
,isnull(sum(vsYTYS.ScYsAreaSum),0) as HTTotleAreaSum
from p_room pr left join vs_YTYS_View vsYTYS
on pr.RoomGUID=vsYTYS.RoomGUID 
where pr.BldGUID in (select BldGUID from s_TjTjResult where TjPlanGUID=@PlanGUID)
group by pr.BldGUID	
) b
on a.BldGUID=b.BldGUID
left join (
--¥���±���δ�ϱ�����
select BldGUID
,isnull(sum(isnull(dbo.[fn_GetRoomTjfAmountSum](RoomGUID),0)),0) as BCRecentlyTotle_WSB		--�Ƿ��ؼ۷�
--BCRecentlyTotle:ȡ¥���б���δ�ϱ��ķ����ڷ����׼��ܼ�(���ؼ۷��߼�ȡ��BCRecentlyTotle_WSB)+���ε���������s_TjTjResult�׼��ܼ�
from p_room 
where BldGUID in (select prr.BldGUID from s_TjTjResult stt left join p_room prr on stt.RoomGUID=prr.RoomGUID where TjPlanGUID=@PlanGUID)
and RoomGUID not in (select RoomGUID from s_TjTjResult where TjPlanGUID=@PlanGUID)
group by BldGUID	
) c
on a.BldGUID=c.BldGUID

--*/



END
ELSE
BEGIN
	PRINT 'δ����۸�'
	
	SELECT 'NOImport' AS ReMesInfo
	
	RETURN

END

GO


ALTER PROCEDURE [dbo].[usp_jg_ProjHz]  
    @PlanGUID VARCHAR(40) 
AS   
BEGIN    

IF @PlanGUID='' 
BEGIN
	RETURN 
END


CREATE TABLE #Show
(
	IDType int,			--��Ŀ12��ҵ̬¥��3
	type int,			--��Ŀ1��ҵ̬2��¥��3
	YTName varchar(200),		--ҵ̬��¥��	
	YTCode varchar(200),		--ҵ̬CODE
	BldCode varchar(200),		--¥��CODE
	ShowType int,					--���1������2����ֵ3
	IsHz int,						--�Ƿ��ֵ(��ֵ�����ݿ�ȡ���Ľ��/10000������4λС��)
	TargetBJArea decimal(23,4),
	TargetDTArea decimal(23,4),
	TZQDT decimal(23,4),
	YTYS decimal(23,4),
	YTWS decimal(23,4),
	BCBP decimal(23,4),  
	WTS decimal(23,4),
	XJ decimal(23,4),
	DiffDt decimal(23,4),
	DiffBeAf decimal(23,4),
	IsXj int
)


--1
--��Ŀ��ֵ�б���Ŀ������������У�:��Ŀ�����������
--���ݱ���Ŀ��ֵ��
--��������������GUID=���η���GUID������=1
INSERT INTO #Show(
	IDType ,type ,YTName ,YTCode ,BldCode,ShowType,IsHz,TargetBJArea ,TargetDTArea ,
	TZQDT ,YTYS , YTWS , BCBP ,  WTS ,XJ ,DiffDt ,DiffBeAf ,IsXj
)
SELECT 1 AS IDType, 1 AS type,'��Ŀ�����������' as YTName,'' AS YTCode,'' AS BldCode,1 AS ShowType,0 as IsHz
,TargetBJArea,TargetDTArea,TZQDT,YTYS,YTWS,BCBP,WTS,XJ
,(XJ-TargetDTArea) AS DiffDt ,(XJ-TZQDT) AS DiffBeAf,0
FROM s_DjTjProjValue
WHERE PlanGUID=@PlanGUID
AND Sort=1

--��Ŀ��ֵ�б���Ŀ�ܻ�ֵ�У�:��Ŀ�ܻ�ֵ(��Ԫ)
INSERT INTO #Show(
	IDType ,type ,YTName ,YTCode ,BldCode,ShowType,IsHz,TargetBJArea ,TargetDTArea ,
	TZQDT ,YTYS , YTWS , BCBP ,  WTS ,XJ ,DiffDt ,DiffBeAf ,IsXj
)
SELECT 2 AS IDType,1 AS type,'��Ŀ�ܻ�ֵ(��Ԫ)' as YTName,'' AS YTCode,'' AS BldCode,1 AS ShowType,1 as IsHz
,round(TargetBJArea/10000.0000,4),round(TargetDTArea/10000.0000,4),round(TZQDT/10000.0000,4),round(YTYS/10000.0000,4)
,round(YTWS/10000.0000,4),round(BCBP/10000.0000,4),round(WTS/10000.0000,4),round(XJ/10000.0000,4)
,(round(XJ/10000.0000,4)-round(TargetDTArea/10000.0000,4)) AS DiffDt ,(round(XJ/10000.0000,4)-round(TZQDT/10000.0000,4)) AS DiffBeAf
,0
FROM s_DjTjProjValue
WHERE PlanGUID=@PlanGUID
AND Sort=2

--2
--ҵ̬��ֵ�б�����У�
--���ݱ�ҵ̬��ֵ��
--��������������GUID=���η���GUID������=1
--ҵ̬���롢��������
--SELECT *  
--FROM data_dict dd
--WHERE dd.table_name='s_DjTjYTValue'

INSERT INTO #Show(
	IDType ,type ,YTName ,YTCode ,BldCode,ShowType,IsHz,TargetBJArea ,TargetDTArea ,
	TZQDT ,YTYS , YTWS , BCBP ,  WTS ,XJ ,DiffDt ,DiffBeAf,IsXj 
)
SELECT 3 AS IDType,2 AS type,b.BProductTypeShortName as YTName,b.BProductTypeCode AS YTCode,'' AS BldCode,1 AS ShowType,0 AS IsHz
,a.TargetBJArea,a.TargetDTArea,a.TZQDT,a.YTYS,a.YTWS,a.BCBP,a.WTS
,a.XJ,(a.XJ-a.TargetDTArea) AS DiffDt ,(a.XJ-a.TZQDT) AS DiffBeAf,1
FROM s_DjTjYTValue a LEFT JOIN p_BuildProductType b
ON a.YTGUID=b.BuildProductTypeGUID
WHERE a.PlanGUID=@PlanGUID
AND a.Sort=1
ORDER BY b.BProductTypeCode


--ҵ̬��ֵ�б������У�
--���ݱ�ҵ̬��ֵ��
--��������������GUID=���η���GUID������=2"																					
--ҵ̬���롢��������	
INSERT INTO #Show(
	IDType ,type ,YTName ,YTCode ,BldCode,ShowType,IsHz,TargetBJArea ,TargetDTArea ,
	TZQDT ,YTYS , YTWS , BCBP ,  WTS ,XJ ,DiffDt ,DiffBeAf ,IsXj
)																			
SELECT 3 AS IDType,2 AS type,b.BProductTypeShortName as YTName,b.BProductTypeCode AS YTCode,'' AS BldCode,2 AS ShowType,0 AS IsHz
,a.TargetBJArea,a.TargetDTArea,a.TZQDT,a.YTYS,a.YTWS,a.BCBP,a.WTS
,a.XJ,(a.XJ-a.TargetDTArea) AS DiffDt ,(a.XJ-a.TZQDT) AS DiffBeAf,1
FROM s_DjTjYTValue a LEFT JOIN p_BuildProductType b
ON a.YTGUID=b.BuildProductTypeGUID
WHERE a.PlanGUID=@PlanGUID
AND a.Sort=2
ORDER BY b.BProductTypeCode

--ҵ̬��ֵ�б���ֵ�У�
--���ݱ�ҵ̬��ֵ��
--��������������GUID=���η���GUID������=3																					
--ҵ̬���롢��������
INSERT INTO #Show(
	IDType ,type ,YTName ,YTCode ,BldCode,ShowType,IsHz,TargetBJArea ,TargetDTArea ,
	TZQDT ,YTYS , YTWS , BCBP ,  WTS ,XJ ,DiffDt ,DiffBeAf ,IsXj
)																				
SELECT 3 AS IDType,2 AS type,b.BProductTypeShortName as YTName,b.BProductTypeCode AS YTCode,'' AS BldCode,3 AS ShowType,1 AS IsHz
--,a.TargetBJArea,a.TargetDTArea,a.TZQDT,a.YTYS,a.YTWS,a.BCBP,a.WTS,a.XJ
--,(a.XJ-a.TargetDTArea) AS DiffDt ,(a.XJ-a.TZQDT) AS DiffBeAf
,round(TargetBJArea/10000.0000,4),round(TargetDTArea/10000.0000,4),round(TZQDT/10000.0000,4),round(YTYS/10000.0000,4)
,round(YTWS/10000.0000,4),round(BCBP/10000.0000,4),round(WTS/10000.0000,4),round(XJ/10000.0000,4)
,(round(XJ/10000.0000,4)-round(TargetDTArea/10000.0000,4)) AS DiffDt ,(round(XJ/10000.0000,4)-round(TZQDT/10000.0000,4)) AS DiffBeAf
,1
FROM s_DjTjYTValue a LEFT JOIN p_BuildProductType b
ON a.YTGUID=b.BuildProductTypeGUID
WHERE a.PlanGUID=@PlanGUID
AND a.Sort=3
ORDER BY b.BProductTypeCode

--3
--¥����ֵ�б�����У�
--���ݱ�¥����ֵ��
--��������������GUID=���η���GUID������=1
--¥�����롢��������
INSERT INTO #Show(
	IDType ,type ,YTName ,YTCode ,BldCode,ShowType,IsHz,TargetBJArea ,TargetDTArea ,
	TZQDT ,YTYS , YTWS , BCBP ,  WTS ,XJ ,DiffDt ,DiffBeAf ,IsXj
)
SELECT 3 AS IDType,3 AS type,gcb.BldName as YTName
--,c.ProductCode
,( SELECT top 1 BProductTypeCode FROM p_BuildProductType WHERE LEVEL=2 and BProductTypeShortName=c.ProductName ) AS YTCode
,(SELECT ProjCode FROM p_project WHERE ProjGUID=gcb.ProjGUID) + '.' + gcb.BldCode
,1 AS ShowType,0 AS IsHz
,a.TargetBJArea,a.TargetDTArea,a.TZQDT,a.YTYS,a.YTWS,a.BCBP,a.WTS
,a.XJ,(a.XJ-a.TargetDTArea) AS DiffDt ,(a.XJ-a.TZQDT) AS DiffBeAf
,0
FROM s_DjTjBldValue a LEFT JOIN dbo.jd_GCBuilding gcb
ON a.BldGUID=gcb.BldGUID
LEFT JOIN cb_HkbProductWork c
ON gcb.ProductGUID=c.ProductGUID
WHERE a.PlanGUID=@PlanGUID
AND a.Sort=1
ORDER BY c.ProductCode,gcb.BldCode

--SELECT * 
--FROM s_DjTjBldValue a LEFT JOIN p_Building b
--ON a.BldGUID=b.BldGUID
--LEFT JOIN cb_HkbProductWork c
--ON b.ProductGUID=c.ProductGUID
--WHERE a.PlanGUID=@PlanGUID
--AND a.Sort=1
--ORDER BY c.ProductCode,b.BldCode

--¥����ֵ�б������У�
--���ݱ�¥����ֵ��
--��������������GUID=���η���GUID������=2
--¥�����롢��������
INSERT INTO #Show(
	IDType ,type ,YTName ,YTCode ,BldCode,ShowType,IsHz,TargetBJArea ,TargetDTArea ,
	TZQDT ,YTYS , YTWS , BCBP ,  WTS ,XJ ,DiffDt ,DiffBeAf ,IsXj
)
SELECT 3 AS IDType,3 AS type,gcb.BldName as YTName
--,c.ProductCode
,( SELECT top 1 BProductTypeCode FROM p_BuildProductType WHERE LEVEL=2 and BProductTypeShortName=c.ProductName ) AS YTCode
,(SELECT ProjCode FROM p_project WHERE ProjGUID=gcb.ProjGUID) + '.' + gcb.BldCode
,2 AS ShowType,0 AS IsHz
,a.TargetBJArea,a.TargetDTArea,a.TZQDT,a.YTYS,a.YTWS,a.BCBP,a.WTS
,a.XJ,(a.XJ-a.TargetDTArea) AS DiffDt ,(a.XJ-a.TZQDT) AS DiffBeAf
,0
FROM s_DjTjBldValue a LEFT JOIN dbo.jd_GCBuilding gcb
ON a.BldGUID=gcb.BldGUID
LEFT JOIN cb_HkbProductWork c
ON gcb.ProductGUID=c.ProductGUID
WHERE a.PlanGUID=@PlanGUID
AND a.Sort=2
ORDER BY c.ProductCode,gcb.BldCode

--¥����ֵ�б���ֵ�У�
--���ݱ�¥����ֵ��
--��������������GUID=���η���GUID������=3
--¥�����롢��������
INSERT INTO #Show(
	IDType ,type ,YTName ,YTCode ,BldCode,ShowType,IsHz,TargetBJArea ,TargetDTArea ,
	TZQDT ,YTYS , YTWS , BCBP ,  WTS ,XJ ,DiffDt ,DiffBeAf ,IsXj
)
SELECT 3 AS IDType,3 AS type,gcb.BldName as YTName
--,c.ProductCode
,( SELECT top 1 BProductTypeCode FROM p_BuildProductType WHERE LEVEL=2 and BProductTypeShortName=c.ProductName ) AS YTCode
,(SELECT ProjCode FROM p_project WHERE ProjGUID=gcb.ProjGUID) + '.' + gcb.BldCode
,3 AS ShowType,1 AS IsHz
,round(TargetBJArea/10000.0000,4),round(TargetDTArea/10000.0000,4),round(TZQDT/10000.0000,4),round(YTYS/10000.0000,4)
,round(YTWS/10000.0000,4),round(BCBP/10000.0000,4),round(WTS/10000.0000,4),round(XJ/10000.0000,4)
,(round(XJ/10000.0000,4)-round(TargetDTArea/10000.0000,4)) AS DiffDt ,(round(XJ/10000.0000,4)-round(TZQDT/10000.0000,4)) AS DiffBeAf
,0
FROM s_DjTjBldValue a LEFT JOIN dbo.jd_GCBuilding gcb
ON a.BldGUID=gcb.BldGUID
LEFT JOIN cb_HkbProductWork c
ON gcb.ProductGUID=c.ProductGUID
WHERE a.PlanGUID=@PlanGUID
AND a.Sort=3
ORDER BY c.ProductCode,gcb.BldCode


--SELECT *  
--FROM data_dict dd
--WHERE dd.table_name='s_DjTjBldValue'


SELECT IDENTITY(int,1,1) AS ID
,IDType ,type ,YTName ,YTCode ,BldCode,ShowType,IsHz ,TargetBJArea ,TargetDTArea ,
	TZQDT ,YTYS , YTWS , BCBP ,  WTS ,XJ ,DiffDt ,DiffBeAf,IsXj 	
INTO #Init									
FROM #Show
ORDER BY IDType,YTCode,IsXj,BldCode,ShowType

--SELECT * 
--FROM #Show
--ORDER BY IDType,YTCode,BldCode,ShowType


DECLARE @IDNum AS varchar(50)
DECLARE @YTName AS varchar(200)
DECLARE @type AS varchar(200)
DECLARE @YTCode AS varchar(200)
DECLARE @BldCode AS varchar(200)
DECLARE @BldName AS varchar(200)

DECLARE @TargetBJArea AS varchar(200) 
DECLARE @TargetDTArea AS varchar(100) 
DECLARE @TZQDT AS varchar(100) 
DECLARE @YTYS AS varchar(100) 
DECLARE @YTWS AS varchar(100) 
DECLARE @BCBP AS varchar(100) 
DECLARE @WTS AS varchar(100) 
DECLARE @XJ AS varchar(100) 
DECLARE @DiffDt AS varchar(100) 
DECLARE @DiffBeAf AS varchar(100) 

DECLARE @ShowType AS varchar(100) 
DECLARE @ShowTypeName AS varchar(100) 
DECLARE @IsHz AS varchar(10)

-----------------------------------------------------
DECLARE @ID AS int
DECLARE @Count AS int 

DECLARE @IsFirstYt AS varchar(100) 
SET @IsFirstYt='1'
DECLARE @IsFirstLd AS varchar(100) 
SET @IsFirstLd='1'

DECLARE @IsHj AS varchar(100) 
SET @IsHj=' IsHj = ''0'' '

DECLARE @align AS varchar(100) 
SET @align=' align = ''left'' '

DECLARE @rowspanYt AS varchar(100) 
SET @rowspanYt='1'
DECLARE @rowspanLd AS varchar(100) 
SET @rowspanLd='1'

DECLARE @rowspanYtNoLd AS varchar(100) 
SET @rowspanYtNoLd='1'
DECLARE @colspan AS varchar(100) 
SET @colspan='1'

DECLARE @xml AS varchar(max)
DECLARE @temp AS varchar(max)
set @xml=''
set @temp=''

--set @tempData=''

--SELECT * FROM #Init

SELECT @Count=Count(1) FROM #Init  
SET @ID=1  

SET @temp=@temp+'<Row>'  

set @ID=1 
while @ID<=@Count  
BEGIN  
 
--------------------------------------------------------------------
	--xl
	SELECT @IDNum=cast(IDType AS varchar(10)),@type=type,@YTCode=YTCode,@BldCode=BldCode,@ShowType=ShowType,@IsHz=IsHz
	,@YTName=(CASE WHEN type in (3) THEN (SELECT YTName FROM #Init r WHERE r.YTCode=#Init.YTCode AND type=2 AND ShowType=1 ) 
				  else YTName end)
	,@BldName=(CASE WHEN type IN (2) THEN 'С��' when type in (3) then YTName ELSE  ''  end)
	,@ShowTypeName = (CASE WHEN type=1 THEN '' ELSE (CASE @ShowType WHEN 1 THEN '�����m2��' WHEN 2 THEN '���ۣ�Ԫ/m2��' when 3 then '��ֵ����Ԫ��' else '' end) end)
	,@rowspanYt = (CASE WHEN type= 1 then '1' 
				   else (SELECT count(1)+3 FROM #Init r WHERE r.YTCode=#Init.YTCode AND type=3  ) end ) --¥��+С����
	,@rowspanLd='3'		--¥��3��
	,@colspan = (CASE WHEN type in (1) THEN '3' else '1' end)	--��Ŀ�кϲ�3��
	,@rowspanYtNoLd = (CASE WHEN type in (1) THEN '1' else '3' end)	--����ʾ¥����ϸ(ֻ��ʾ��Ŀ��ҵ̬С��)����Ŀ���У�ҵ̬3��
	
	,@IsFirstYt=(CASE WHEN type in (1) THEN '1' 
					when type in (2,3) then 
						(case when ID=(select min(ID) from #Init r where r.YTCode=#Init.YTCode)
						then '1' else '0' end)   
					else '' end) 

	,@IsFirstLd=(CASE when type in (2,3) then (case when ShowType=1 then '1' else '0' end)  else '0' end) 
	
	,@TargetBJArea=TargetBJArea
	,@TargetDTArea=TargetDTArea,@TZQDT=TZQDT
	,@YTYS=YTYS,@YTWS=YTWS
	,@BCBP=BCBP,@WTS=WTS
	,@XJ=XJ,@DiffDt=DiffDt
	,@DiffBeAf=DiffBeAf
	FROM #Init
	WHERE ID=@ID

	--------------------------------------------------------------------
	--set @Memo=replace(replace(replace(replace(replace(@Memo,'&','&amp;'),'<','&lt;'),'>','&gt;'),'''','&apos; '),'"','&quot;') 		

	SET @temp=@temp+'<Dtl '  + ' ID=''' + @IDNum + '''  YTName='''+  @YTName +'''  type='''+ @type+''' ' 
					+'  IsFirstYt=''' + @IsFirstYt+ '''   '
					+'  IsFirstLd=''' + @IsFirstLd+ '''   '
					+'  BldName=''' + @BldName+ '''   '
					+'  ShowType=''' + @ShowType+ '''   '
					+'  IsHz=''' + @IsHz+ '''   '
					+'  rowspanYt=''' + @rowspanYt+ '''   '
					+'  rowspanYtNoLd=''' + @rowspanYtNoLd+ '''   '
					+'  rowspanLd=''' + @rowspanLd+ '''   '
					+'  colspan=''' + @colspan+ '''   '
					+'  ShowTypeName=''' + @ShowTypeName+ '''   '
					+'  YTCode=''' + @YTCode+ '''   '
					+'  BldCode=''' + @BldCode+ '''   '
					+'  TargetBJArea=''' + @TargetBJArea+ '''   '
					+'  TargetDTArea=''' + @TargetDTArea + '''   '	
					+'  TZQDT=''' + @TZQDT + '''   '
					+'  YTYS=''' + @YTYS + '''   '
					+'  YTWS=''' + @YTWS + '''   '
					+'  BCBP=''' + @BCBP + '''   '		
					+'  WTS=''' + @WTS + '''   '
					+'  XJ=''' + @XJ + '''   '+'  DiffDt=''' + @DiffDt + '''   '		
					+'  DiffBeAf=''' + @DiffBeAf + '''   '
					+' >' 
					+ '</Dtl>'     


 
 set @ID=@ID+1  
END  


SET @temp=@temp+ '</Row>'   



SET @xml='<xml>'  + @temp  + '</xml>'  


SELECT  @xml
SELECT 
(CASE WHEN type in (3) THEN (SELECT YTName FROM #Init r WHERE r.YTCode=#Init.YTCode AND type=2 AND ShowType=1 ) 
				  else YTName end) as YTName
,(CASE WHEN type IN (2) THEN 'С��' when type in (3) then YTName ELSE  ''  end) as BldName
,(CASE WHEN type= 1 then '1' 
				   else (SELECT count(1)+1 FROM #Init r WHERE r.YTCode=#Init.YTCode AND type=3 ) end ) --¥��+С����
				    AS rowspanYt

,(CASE WHEN type in (1) THEN '1' 
when type in (2,3) then 
	(case when ID=(select min(ID) from #Init r where r.YTCode=#Init.YTCode)
	then '1' else '0' end)   
else '' end) AS IsFirstYt

,(CASE when type in (2,3) then (case when ShowType=1 then '1' else '0' end)  else '0' end) AS IsFirstLd
,IsXj
,YTCode
,* 
FROM #Init
ORDER BY IDType,#Init.YTCode,#Init.IsXj,BldCode,ShowType


END   


GO




