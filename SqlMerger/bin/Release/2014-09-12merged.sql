--copy right sunsoft
--Created At :2014-09-12 05:01:57
--Created By :MYSOFT\sunr01
--函数判断一个工程楼栋是否未推售(不考虑存在调价方案中的楼栋)
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
	@BldGUID  varchar(40)	--工程楼栋guid
    )
RETURNS int
AS 
	BEGIN
		
		DECLARE @r AS INT
		DECLARE @totaldj AS MONEY
		SET @r=0
		SET @totaldj=0
		--求当前工程楼栋对应的销售楼栋对应的底总价
		SELECT @totaldj=ISNULL(SUM(ISNULL(TotalDj,0)),0)
		FROM dbo.jd_GCBuilding gcb
		INNER JOIN dbo.p_Building pb ON pb.ParentCode + '.' + pb.BldCode = gcb.BldFullCode
		INNER JOIN dbo.p_Room room ON room.BldGUID=pb.BldGUID
		WHERE gcb.BldGUID=@BldGUID
		
		--是否  楼栋未推售
		IF EXISTS(
			SELECT 1
			FROM dbo.jd_GCBuilding gcb
			LEFT JOIN dbo.p_Building pb ON pb.ParentCode + '.' + pb.BldCode = gcb.BldFullCode
			LEFT JOIN dbo.p_Room room ON room.BldGUID=pb.BldGUID
			WHERE gcb.BldGUID=@BldGUID
			AND (pb.BldGUID IS NULL	--未被引入
				OR (pb.BldGUID IS NOT NULL AND NOT EXISTS(SELECT RoomGUID FROM dbo.p_Room WHERE BldGUID=pb.BldGUID)) --被引入，但未建立房间
				OR (pb.BldGUID IS NOT NULL AND EXISTS(SELECT RoomGUID FROM dbo.p_Room WHERE BldGUID=pb.BldGUID) AND @totaldj=0)
				)
		)
		BEGIN
				set @r=1
		END

		RETURN @r
		
	END
 GO 


--本函数兼顾工程楼栋和销售楼栋
-------------------------
  
ALTER  FUNCTION [dbo].[fn_GetYtNameFromBld]
    (
      @BldGUID UNIQUEIDENTIFIER ,		--楼栋GUID
      @BldType AS VARCHAR(20)		--楼栋类型
    )
RETURNS VARCHAR(200)
AS
    BEGIN  
 --在工程楼栋表找该楼栋的ProductGUID，在从产品类型表（cb_HkbProductWork）中找BProductTypeName   
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
                SET @r = '其他'
            END
        RETURN @r  
   
    END  

GO






ALTER  FUNCTION [dbo].[fn_IsWTsBldAndNoBcPlan](
	@BldGUID  varchar(40),	--工程楼栋GUID
	@PlanGUID varchar(40)	--调价方案GUID
)
RETURNS int
AS
BEGIN
	
	DECLARE @r AS int
	SET @r=0
	--是否  楼栋未推售且不在本次报批中
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
	@BldGUID  varchar(40),	--工程楼栋GUID
	@PlanGUID varchar(40)	--调价方案GUID
)
RETURNS int
AS
BEGIN
	
	DECLARE @r AS int
	SET @r=0
	--是否  楼栋未推售且不在本次报批中
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




--函数判断一个工程楼栋是否未推售(不考虑存在调价方案中的楼栋)
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
	@BldGUID  varchar(40),		--工程楼栋guid
	@CalcType varchar(50),		--计算类型
	@PlanGUID UNIQUEIDENTIFIER	--调价方案GUID
    )
RETURNS DECIMAL(23,4)
AS 
	BEGIN
		--定义变量
		DECLARE @r AS DECIMAL(23,4)
		--
		IF @CalcType='bcbp_area_any' --无论是wts还是其它
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
		--当前楼栋是未推售
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
						SET @r=0	--未推售的楼栋的已推已售字段默认为0
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
			--当前楼栋是已推售
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
						AND EXISTS(SELECT 1 FROM s_trade WHERE RoomGUID=room.RoomGUID AND TradeStatus='激活')
						AND Status IN ('认购','签约')
					END
				ELSE IF @CalcType='tzqdt_hz'
					BEGIN
						SET @r=0 --ScData里面计算了，已推售部分的，所以这里为0
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
						AND EXISTS(SELECT 1 FROM s_trade WHERE RoomGUID=room.RoomGUID AND ISNULL(TradeStatus,'')<>'激活')
						AND Status IN ('认购','签约')
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
						AND EXISTS(SELECT 1 FROM s_trade WHERE RoomGUID=room.RoomGUID AND ISNULL(TradeStatus,'')<>'激活')
						AND Status IN ('认购','签约')
						AND room.RoomGUID not IN (SELECT RoomGUID FROM dbo.s_DjTjResult WHERE PlanGUID=@PlanGUID)
					END
			END
		RETURN @r
		
	END
 GO 


--函数判断一个工程楼栋是否未推售(不考虑存在调价方案中的楼栋)
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
	@BldGUID  varchar(40),		--工程楼栋guid
	@CalcType varchar(50),		--计算类型
	@PlanGUID UNIQUEIDENTIFIER	--调价方案GUID
    )
RETURNS DECIMAL(23,4)
AS 
	BEGIN
		--定义变量
		DECLARE @r AS DECIMAL(23,4)
		--
		IF @CalcType='bcbp_area_any' --无论是wts还是其它
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
		--当前楼栋是未推售
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
						SET @r=0	--未推售的楼栋的已推已售字段默认为0
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
			--当前楼栋是已推售
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
						AND EXISTS(SELECT 1 FROM s_trade WHERE RoomGUID=room.RoomGUID AND TradeStatus='激活')
						AND Status IN ('认购','签约')
					END
				ELSE IF @CalcType='tzqdt_hz'
					BEGIN
						SET @r=0 --ScData里面计算了，已推售部分的，所以这里为0
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
						AND EXISTS(SELECT 1 FROM s_trade WHERE RoomGUID=room.RoomGUID AND ISNULL(TradeStatus,'')<>'激活')
						AND Status IN ('认购','签约')
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
						AND EXISTS(SELECT 1 FROM s_trade WHERE RoomGUID=room.RoomGUID AND ISNULL(TradeStatus,'')<>'激活')
						AND Status IN ('认购','签约')
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

DECLARE @ProjGUID AS varchar(40)	--一级项目GUID
DECLARE @ParentCode AS varchar(40)  --一级项目ProjCode

--调价方案在一级项目
SELECT @ProjGUID=ProjGUID
FROM s_DjTjPlan 
WHERE PlanGUID=@PlanGUID

SELECT @ParentCode = ProjCode
FROM p_project
WHERE ProjGUID=@ProjGUID



--生成前，先删除【本次拟报资源表】、【项目货值表】、【业态货值表】、【楼栋货值表】、
--【楼栋信息分析表】、【批次信息分析表】、【价格异常房间表】、【试算房间明细表】
--生成后，刷新4个页签的所有列表
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
--WHERE dd.table_name_c='价格异常房间表'

--SELECT * FROM myAction 
--WHERE ObjectType='01010109'

--是否导入模板
IF EXISTS(SELECT 1 FROM s_DjTjResult WHERE PlanGUID=@PlanGUID)
BEGIN
	PRINT '已导入价格'

--生成本次报价资源情况-C1（本次导入的房间范围）
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

--------------[进入本次修改区域:2014-09-11]-------------

--1.1----------------------------------------------------
--生成项目货值(面积)-C2
declare @TargetBJArea_Proj_Area as decimal(23,4)=0.0000
declare @TargetDTArea_Proj_Area as decimal(23,4)=0.0000
declare @TZQDT_Proj_Area as decimal(23,4)=0.0000
declare @YTYS_Proj_Area as decimal(23,4)=0.0000
declare @YTWS_Proj_Area as decimal(23,4)=0.0000
declare @BCBP_Proj_Area as decimal(23,4)=0.0000
declare @WTS_Proj_Area as decimal(23,4)=0.0000
declare @XJ_Proj_Area as decimal(23,4)=0.0000

--目标报建面积					
--TargetBJArea					
--当前一级项目下所有末级项目的销售楼栋在商业计划书表（ys_BusinessPlan）中
--对应的工程楼栋的KsArea可售面积
select @TargetBJArea_Proj_Area=isnull(sum(isnull(gcb.KsArea,0)),0)
FROM dbo.jd_GCBuilding gcb 
where gcb.ProjGUID in (
SELECT ProjGUID FROM p_project WHERE ParentCode=@ParentCode
)

--目标动态面积
--TargetDTArea
--当前一级项目下所有未推售的工程楼栋取工程楼栋表中的KsArea可售面积
--+一级项目下所有已推售楼栋所有房间预售面积（P_ROOM.YsBldArea）之和
select @TargetDTArea_Proj_Area = isnull(sum(isnull(dbo.fn_CalcBldValue(gcb.BldGUID,'targetdtarea',@PlanGUID),0)),0)
FROM dbo.jd_GCBuilding gcb 
where gcb.ProjGUID in (
SELECT ProjGUID FROM p_project WHERE ParentCode=@ParentCode
)



--调整前动态值
--TZQDT
--当前一级项目下所有未推售未推售的工程楼栋取工程楼栋表中的KsArea可售面积
--+一级项目下所有已推售楼栋所有房间最新建筑面积之和（有实测面积的取实测面积（ScBldArea），实测为0的取预售面积）													
select @TZQDT_Proj_Area = isnull(sum(isnull(dbo.fn_CalcBldValue(gcb.BldGUID,'tzqdt',@PlanGUID),0)),0)
FROM dbo.jd_GCBuilding gcb 
where gcb.ProjGUID in (
SELECT ProjGUID FROM p_project WHERE ParentCode=@ParentCode
)

--已推已售					
--YTYS
--当前一级项目下所有已推已售的房间在房间表的ScBldArea合计，如ScBldArea为0则取该房间的YsBldArea													
select @YTYS_Proj_Area= isnull(sum(isnull(dbo.fn_CalcBldValue(gcb.BldGUID,'ytys_area',@PlanGUID),0)),0)
FROM dbo.jd_GCBuilding gcb 
where gcb.ProjGUID in (
SELECT ProjGUID FROM p_project WHERE ParentCode=@ParentCode
)

--已推未售
--YTWS
--当前一级项目已推楼栋下除本次报批外的 所有已推未售的房间在房间表的ScBldArea合计，如ScBldArea为0则取该房间的YsBldArea
select @YTWS_Proj_Area=isnull(sum( case when isnull(ScBldArea,0)=0 then isnull(YsBldArea,0) else isnull(ScBldArea,0) end  ),0)
from p_room
where BldGUID in 
(

	select pb.BldGUID
	FROM p_Building pb 
	where pb.ProjGUID in (
	SELECT ProjGUID FROM p_project WHERE ParentCode=@ParentCode
	) 
	AND  --已推楼栋
	(
	Not EXISTS(SELECT 1 FROM p_room WHERE BldGUID=pb.BldGUID AND TotalDj=0)
	AND 
	EXISTS(SELECT 1 FROM p_room WHERE BldGUID=pb.BldGUID)
	)
	and pb.IsBld=1
)
and RoomGUID not in (select RoomGUID from s_DjTjResult where PlanGUID=@PlanGUID)
and NOT EXISTS(SELECT 1 FROM s_trade WHERE RoomGUID=p_room.RoomGUID AND TradeStatus='激活')
AND Status NOT IN ('认购','签约')

--本次报批
--BCBP
--s_DjTjResult表的房间的ScBldArea合计，如ScBldArea为0则取该房间的YsBldArea													
select @BCBP_Proj_Area=isnull(sum( case when isnull(pr.ScBldArea,0)=0 then isnull(pr.YsBldArea,0) else isnull(pr.ScBldArea,0) end  ) ,0)
from s_DjTjResult sdt left join p_room pr
on sdt.RoomGUID=pr.RoomGUID
where sdt.PlanGUID=@PlanGUID



--未推售
--WTS
--孙瑞增加[加上未引入的即可]
SELECT @WTS_Proj_Area=ISNULL(SUM(gcb.KsArea),0.00)
FROM dbo.jd_GCBuilding  gcb
--未被引用的楼栋
WHERE gcb.BldFullCode NOT IN
(
	SELECT p_Building.ParentCode + '.' + p_Building.BldCode
	FROM dbo.p_Project
	INNER JOIN dbo.p_Building ON dbo.p_Building.ProjGUID = dbo.p_Project.ProjGUID
	WHERE p_Project.ParentCode=@ParentCode	--一级项目的子项目code
)
AND gcb.ProjGUID IN
(
	SELECT ProjGUID FROM dbo.p_Project WHERE ParentCode=@ParentCode
)
SELECT @WTS_Proj_Area=@WTS_Proj_Area+ISNULL(SUM(gcb.KsArea),0.00)
FROM dbo.jd_GCBuilding  gcb
--被引用的楼栋,无房间
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
--被引用，有房间，但是底总价之和0
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
	--这里取本次报批的房间
	SELECT pbld.ParentCode + '.' + pbld.BldCode
	FROM dbo.s_DjTjResult
	INNER JOIN dbo.p_Building pbld ON pbld.BldGUID = dbo.s_DjTjResult.BldGUID
)
--End Of 孙瑞添加

--小计
--XJ
--已推已售+已推未售+本次报批+未推售
set @XJ_Proj_Area = @YTYS_Proj_Area+@YTWS_Proj_Area+@BCBP_Proj_Area+@WTS_Proj_Area


insert into s_DjTjProjValue(DjTjProjValueGUID,PlanGUID
,TargetBJArea,TargetDTArea
,TZQDT,YTYS,YTWS,BCBP,WTS,XJ
,Sort,ProjGUID)
select dbo.SeqNewId() as DjTjProjValueGUID,@PlanGUID
,@TargetBJArea_Proj_Area,@TargetDTArea_Proj_Area
,@TZQDT_Proj_Area,@YTYS_Proj_Area,@YTWS_Proj_Area,@BCBP_Proj_Area,@WTS_Proj_Area,@XJ_Proj_Area
,1,@ProjGUID



-----------以上代码,完成时间:2014年9月11日20:11:23
--1.2----------------------------------------------------
--生成项目货值(金额)-C2
declare @TargetBJArea_Proj_Hz as decimal(23,4)=0.0000
declare @TargetDTArea_Proj_Hz as decimal(23,4)=0.0000
declare @TZQDT_Proj_Hz as decimal(23,4)=0.0000
declare @YTYS_Proj_Hz as decimal(23,4)=0.0000
declare @YTWS_Proj_Hz as decimal(23,4)=0.0000
declare @BCBP_Proj_Hz as decimal(23,4)=0.0000
declare @WTS_Proj_Hz as decimal(23,4)=0.0000
declare @XJ_Proj_Hz as decimal(23,4)=0.0000

--目标报建面积					
--TargetBJArea					
--当前一级项目下所有末级项目的销售楼栋在商业计划书表（ys_BusinessPlan）中
--对应的最新版本的每个预算楼栋的基准目标总价（ys_BusinessPlanDtl.TotalAmount）合计
select @TargetBJArea_Proj_Area=isnull(sum(isnull(gcb.YSMBTotle,0)),0)
FROM dbo.jd_GCBuilding gcb 
where gcb.ProjGUID in (
SELECT ProjGUID FROM p_project WHERE ParentCode=@ParentCode
)

--目标动态面积
--TargetDTArea
--当前一级项目下所有未推售的取商业计划书中最新版本所有楼栋的基准目标总价之和
--+已推售楼栋下所有房间的商业计划分户总价p_room.PlanTotal之和

select @TargetDTArea_Proj_Area = isnull(sum(isnull(dbo.fn_CalcBldValue(gcb.BldGUID,'targetdtarea_hz',@PlanGUID),0)),0)
FROM dbo.jd_GCBuilding gcb 
where gcb.ProjGUID in (
SELECT ProjGUID FROM p_project WHERE ParentCode=@ParentCode
)


--调整前动态值
--TZQDT
--当前一级项目下所有已推已售房间总价合计
--+所有已推未售房间总价合计
--+未推售的工程楼栋YSMBTotle
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
	AND --已推楼栋
	(
	Not EXISTS(SELECT 1 FROM p_room WHERE BldGUID=pb.BldGUID AND TotalDj=0)
	AND 
	EXISTS(SELECT 1 FROM p_room WHERE BldGUID=pb.BldGUID)
	)
	and pb.IsBld=1
)
AND EXISTS(SELECT 1 FROM s_trade WHERE RoomGUID=pr.RoomGUID AND TradeStatus='激活')
AND pr.Status IN ('认购','签约')

select @TZQDT_Proj_Hz = @TZQDT_Proj_Hz + isnull(sum(ISNULL([dbo].[fn_GetRoomYTWS](pr.RoomGUID),0)),0)
from p_room pr 
where BldGUID in 
(
	select BldGUID
	FROM p_Building pb 
	where pb.ProjGUID in (
	SELECT ProjGUID FROM p_project WHERE ParentCode=@ParentCode
	) 
	AND --已推楼栋
	(
	Not EXISTS(SELECT 1 FROM p_room WHERE BldGUID=pb.BldGUID AND TotalDj=0)
	AND 
	EXISTS(SELECT 1 FROM p_room WHERE BldGUID=pb.BldGUID)
	)
	and pb.IsBld=1
)
AND NOT EXISTS(SELECT 1 FROM s_trade WHERE RoomGUID=pr.RoomGUID AND TradeStatus='激活')
AND pr.Status NOT IN ('认购','签约')

select @TZQDT_Proj_Hz = @TZQDT_Proj_Hz + isnull(sum(ISNULL([dbo].[fn_CalcBldValue](gcb.BldGUID,'tzqdt_hz',@PlanGUID),0)),0)
FROM dbo.jd_GCBuilding gcb 
where gcb.ProjGUID in (
SELECT ProjGUID FROM p_project WHERE ParentCode=@ParentCode
)



--已推已售					
--YTYS
--当前一级项目下所有已推已售房间总价合计
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
	AND --已推楼栋
	(
	Not EXISTS(SELECT 1 FROM p_room WHERE BldGUID=pb.BldGUID AND TotalDj=0)
	AND 
	EXISTS(SELECT 1 FROM p_room WHERE BldGUID=pb.BldGUID)
	)
	and pb.IsBld=1
)
AND EXISTS(SELECT 1 FROM s_trade WHERE RoomGUID=pr.RoomGUID AND TradeStatus='激活')
AND pr.Status IN ('认购','签约')

--已推未售
--YTWS
--当前一级项目下除本次报批房间外的所有已推未售房间的底价总价合计
select @YTWS_Proj_Hz=isnull(sum(ISNULL([dbo].[fn_GetRoomYTWS](RoomGUID),0)),0)
from p_room
where BldGUID in 
(

	select pb.BldGUID
	FROM p_Building pb 
	where pb.ProjGUID in (
	SELECT ProjGUID FROM p_project WHERE ParentCode=@ParentCode
	) 
	and	--已推楼栋
	(
	Not EXISTS(SELECT 1 FROM p_room WHERE BldGUID=pb.BldGUID AND TotalDj=0)
	AND 
	EXISTS(SELECT 1 FROM p_room WHERE BldGUID=pb.BldGUID)
	)
	and pb.IsBld=1
)
and RoomGUID not in (select RoomGUID from s_DjTjResult where PlanGUID=@PlanGUID)
and NOT EXISTS(SELECT 1 FROM s_trade WHERE RoomGUID=p_room.RoomGUID AND TradeStatus='激活')
AND Status NOT IN ('认购','签约')

--本次报批
--BCBP
--s_DjTjResult表的房间的底价总价TotalDj合计												
select @BCBP_Proj_Hz=isnull(sum( isnull(sdt.TotalDj,0)) ,0)
from s_DjTjResult sdt 
where sdt.PlanGUID=@PlanGUID

--未推售
--WTS
--孙瑞增加[加上未引入的即可]
SELECT @WTS_Proj_Hz=ISNULL(SUM(gcb.YSMBTotle),0.00)
FROM dbo.jd_GCBuilding  gcb
--未被引用的楼栋
WHERE gcb.BldFullCode NOT IN
(
	SELECT p_Building.ParentCode + '.' + p_Building.BldCode
	FROM dbo.p_Project
	INNER JOIN dbo.p_Building ON dbo.p_Building.ProjGUID = dbo.p_Project.ProjGUID
	WHERE p_Project.ParentCode=@ParentCode	--一级项目的子项目code
)
AND gcb.ProjGUID IN
(
	SELECT ProjGUID FROM dbo.p_Project WHERE ParentCode=@ParentCode
)
SELECT @WTS_Proj_Hz=@WTS_Proj_Hz+ISNULL(SUM(gcb.YSMBTotle),0.00)
FROM dbo.jd_GCBuilding  gcb
--被引用的楼栋,无房间
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
--被引用，有房间，但是底总价之和0
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
	--这里取本次报批的房间
	SELECT pbld.ParentCode + '.' + pbld.BldCode
	FROM dbo.s_DjTjResult
	INNER JOIN dbo.p_Building pbld ON pbld.BldGUID = dbo.s_DjTjResult.BldGUID
)
--End Of 孙瑞添加

--小计
--XJ
--已推已售+已推未售+本次报批+未推售
set @XJ_Proj_Hz = @YTYS_Proj_Hz+@YTWS_Proj_Hz+@BCBP_Proj_Hz+@WTS_Proj_Hz

insert into s_DjTjProjValue(DjTjProjValueGUID,PlanGUID
,TargetBJArea,TargetDTArea
,TZQDT,YTYS,YTWS,BCBP,WTS,XJ
,Sort,ProjGUID)
select dbo.SeqNewId() as DjTjProjValueGUID,@PlanGUID
,@TargetBJArea_Proj_Hz,@TargetDTArea_Proj_Hz
,@TZQDT_Proj_Hz,@YTYS_Proj_Hz,@YTWS_Proj_Hz,@BCBP_Proj_Hz,@WTS_Proj_Hz,@XJ_Proj_Hz
,2,@ProjGUID



---------以上，完成：2014年9月11日20:48:26
--1.3.1---------------------------------------------------
--生成楼栋货值（面积）-C3

--TargetBJArea
--销售楼栋在商业计划书表（ys_BusinessPlan）中对应的最新版本的预算楼栋的建筑面积（ys_BusinessPlanDtl.BldArea）
--TargetDTArea
--楼栋未推售取商业计划书中最新版本的楼栋建筑面积,楼栋已推售取楼栋下所有房间预售面积之和p_room.YsBldArea
--TZQDT
--楼栋未推售取商业计划书中最新版本的楼栋建筑面积
--楼栋已推售取楼栋下所有房间实测面积p_room.ScBldArea之和（实测面积为0取房间的预售面积）
--YTYS
--楼栋下所有已推已售的房间在房间表的ScBldArea合计，如ScBldArea为0则取该房间的YsBldArea
--YTWS
--楼栋下除本次报批外的所有已推未售的房间在房间表的ScBldArea合计，如ScBldArea为0则取该房间的YsBldArea

--BCBP
--s_DjTjResult表的房间的ScBldArea合计，如ScBldArea为0则取该房间的YsBldArea
--WTS
--楼栋未推售且不在本次报批内，取商业计划书中最新版本的楼栋建筑面积(设计确认就是0)
--楼栋已推售取0
--XJ
--已推已售+已推未售+本次报批+未推售

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
--将WTS的值，根据工程楼栋关联到销售楼栋
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
--生成楼栋货值（货值）-C3
--TargetBJArea
--销售楼栋在商业计划书表（ys_BusinessPlan）中对应的最新版本的预算楼栋的基准目标总价（ys_BusinessPlanDtl.TotalAmount）
--TargetDTArea
--楼栋未推售取商业计划书中最新版本的楼栋基准目标总价
--楼栋已推售取楼栋下所有房间商业计划总价p_room.PlanTotal
--TZQDT
--楼栋未推售取商业计划书中最新版本的楼栋基准目标总价
--楼栋已推售取楼栋下所有已推已售的房间总价合计+已推未售的房间总价合计
--YTYS
--楼栋下所有已推已售的房间总价合计
--YTWS
--楼栋下除本次报批外的所有已推未售的房间总价合计

--BCBP
--s_DjTjResult表的房间的底价总价TotalDj合计
--WTS
--楼栋未推售且不在本次报批内，取商业计划书中最新版本的楼栋基准目标总价(设计确认就是0)
--楼栋已推售取0
--XJ
--已推已售+已推未售+本次报批+未推售

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
,dbo.[fn_GetYtNameFromBld](gcb.BldGUID,'gcbuilding') as YTName  --数据引自p_BuildProductType（level=2）
into #tempC3_Hz
FROM dbo.jd_GCBuilding gcb
where gcb.ProjGUID in (
SELECT ProjGUID FROM p_project WHERE ParentCode=@ParentCode
)


--******sunsoft area************
--将WTS的值，根据工程楼栋关联到销售楼栋
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
--生成楼栋货值（均价）-C3

--楼栋的货值/面积
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
--生成业态货值（面积）-C4
--汇总一级项目的该业态下所有楼栋的对应指标合计

--业态(cb_HkbProductWork.ProductGUID)引自 产品类型(cb_HkbProductWork.ProductName,cb_HkbProductWork.BProductTypeCode)，
--所以多个业态可以挂在同一个产品类型下

select 
( SELECT top 1 BuildProductTypeGUID FROM p_BuildProductType WHERE LEVEL=2 and BProductTypeShortName=#tempC3_Area.YTName ) as YTGUID  --level2下不会重复
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
--生成业态货值（货值）-C4
--汇总一级项目的该业态下所有楼栋的对应指标合计
select 
--ProductGUID as YTGUID
( SELECT top 1 BuildProductTypeGUID FROM p_BuildProductType WHERE LEVEL=2 and BProductTypeShortName=#tempC3_Hz.YTName ) as YTGUID  --level2下不会重复
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
--生成业态货值（均价）-C4
--业态的货值/面积
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
--生成楼栋信息分析-C5
--Ts:以楼栋维度汇总s_DjTjResult表中每个楼栋下本次上报的房间套数
--BldArea:以楼栋维度汇总s_DjTjResult表中每个楼栋下本次上报的房间在房间表的实测建筑面积p_room.ScBldArea（实测为0取预售建筑面积YsBldArea）
--ZTs:以楼栋维度汇总每个楼栋房间套数
--ZBldArea:以楼栋维度汇总每个楼栋下所有房间在房间表的预售建筑面积p_room.YsBldArea
--BuAmount:取商业计划书中最新版本的楼栋基准目标单价ys_BusinessPlanDtl.Amount
--BuTotle:取商业计划书中最新版本的楼栋基准目标总价ys_BusinessPlanDtl.TotalAmount
--FHAmount:取楼栋中本次上报的房源的商业计划分户总价之和s_DjTjResult.TotalBu/对应房间的预售面积p_room.Ysbldarea之和
--FHTotle:取楼栋中本次上报的房源的商业计划分户总价s_DjTjResult.TotalBu合计
--HTAmount:楼栋下所有已推已售的房间总价合计/房间的实测建筑面积合计p_room.ScBldArea（实测面积为0取预售建筑面积）
--HTTotle:楼栋下所有已推已售的房间总价合计
--RecentlyAmount:取楼栋中所有房间在房间表的底价总价p_room.TotleDj合计（房间存在有效特价时当前系统时间在特价生效和失效日期间，取TotalTj）
--/对应房间实测建筑面积p_room.ScBldArea之和（实测为0取预售）
--RecentlyTotle:取楼栋中所有房间在房间表的底价总价p_room.TotleDj合计（房间存在有效特价时当前系统时间在特价生效和失效日期间，取TotalTj）
--BCRecentlyAmount:取楼栋中（本次未上报的房间在房间表底价总价p_room.TotleDj合计+本次调整房间在s_DjTjResult底价总价TotleDj合计）
--/对应房间实测建筑面积p_room.ScBldArea之和（无实测取预售）
--BCRecentlyTotle:取楼栋中本次未上报的房间在房间表底价总价+本次调整房间在s_DjTjResult底价总价

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
--HTAmount:楼栋下所有已推已售的房间总价合计/房间的实测建筑面积合计p_room.ScBldArea（实测面积为0取预售建筑面积）
,(case when isnull(b.HTTotleAreaSum,0)=0 then 0 else round( isnull(b.HTTotle,0)*1.0/b.HTTotleAreaSum,4) end) as HTAmount
,b.HTTotle
,(case when isnull(b.ScYsBldArea,0)=0 then 0 else round( isnull(b.RecentlyTotle,0)*1.0/b.ScYsBldArea,4) end) as RecentlyAmount
,b.RecentlyTotle
--BCRecentlyAmount:取楼栋中（本次未上报的房间在房间表底价总价(按特价房逻辑取数)合计+本次调整房间在s_DjTjResult底价总价TotleDj合计）
--/对应房间实测建筑面积p_room.ScBldArea之和（无实测取预售）
,(case when isnull(b.ScYsBldArea,0)=0 then 0 else round( (isnull(c.BCRecentlyTotle_WSB,0)+isnull(a.BCRecentlyTotle_BCTZ,0))*1.0/b.ScYsBldArea,4) end) as BCRecentlyAmount
--BCRecentlyTotle:取楼栋中本次未上报的房间在房间表底价总价+本次调整房间在s_DjTjResult底价总价
,(isnull(c.BCRecentlyTotle_WSB,0)+isnull(a.BCRecentlyTotle_BCTZ,0)) as BCRecentlyTotle
--,isnull(c.BCRecentlyTotle_WSB,0),isnull(a.BCRecentlyTotle_BCTZ,0)
from 
(
--楼栋下本次上报房间
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
--楼栋下所有房间
select pr.BldGUID
,count(1) as ZTs
,isnull(sum(isnull(pr.YsBldArea,0)),0) as ZBldArea
,isnull(sum(isnull([dbo].[fn_GetRoomTjfAmountSum](pr.RoomGUID),0)),0) as RecentlyTotle
,isnull(sum( case when isnull(pr.ScBldArea,0)=0 then isnull(pr.YsBldArea,0) else isnull(pr.ScBldArea,0) end  ) ,0) as ScYsBldArea
--HTTotle:楼栋下所有已推已售的房间总价合计
,ISNULL(sum(isnull(vsYTYS.YTYS,0)),0) as HTTotle
,isnull(sum(vsYTYS.ScYsAreaSum),0) as HTTotleAreaSum
from p_room pr left join vs_YTYS_View vsYTYS
on pr.RoomGUID=vsYTYS.RoomGUID 
where pr.BldGUID in (select BldGUID from s_DjTjResult where PlanGUID=@PlanGUID)
group by pr.BldGUID	
) b
on a.BldGUID=b.BldGUID
left join (
--楼栋下本次未上报房间
select BldGUID
,isnull(sum(isnull(dbo.[fn_GetRoomTjfAmountSum](RoomGUID),0)),0) as BCRecentlyTotle_WSB		--是否特价房
--BCRecentlyTotle:取楼栋中本次未上报的房间在房间表底价总价(按特价房逻辑取数BCRecentlyTotle_WSB)+本次调整房间在s_DjTjResult底价总价
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
	PRINT '未导入价格'
	
	--生成价格异常房间-C7
	--循环当前调价方案所属一级项目下的所有房间，判断每个房间的最大优惠后总价是否低于房间的底价总价，
	--如低于底价总价，则向下表插入房间记录

--	


END

 
--生成价格异常房间-C7
--最大优惠后总价:
--（房间标准总价（房间在本次调价方案的s_DjTjResult存在取s_DjTjResult表的现标准总价Total
--不存在取房间表的标准总价Total）-现优惠金额）*（1-现优惠减点）
--DECLARE @PlanGUID AS varchar(40)='2B721174-9DBB-E311-80DB-00155D0A6F0B'

--房间的底价总价:TotalDj	底价总价
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
--（房间表的标准总价Total-房间所在楼栋的楼栋减金额p_Building.YHAmount）*（1-房间所在楼栋的楼栋减点p_Building.YHPoint）!减点除以100
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

--（过滤掉已推已售的房间）
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
		 --已推楼栋
		(
		Not EXISTS(SELECT 1 FROM p_room WHERE BldGUID=pr.BldGUID AND TotalDj=0)
		AND 
		EXISTS(SELECT 1 FROM p_room WHERE BldGUID=pr.BldGUID)
		)
		AND EXISTS(SELECT 1 FROM s_trade WHERE RoomGUID=pr.RoomGUID AND TradeStatus='激活')
		AND Status IN ('认购','签约')
)

--生成房间明细-C8
SELECT sdt.PlanGUID,pr.BldGUID,sdt.RoomGUID,pr.BldArea,pr.TnArea
,sdt.PriceBu,sdt.TnPriceBu,sdt.TotalBu
,sdt.OriginalPriceDj,sdt.OriginalTnPriceDj,sdt.OriginalTotalDj,sdt.PriceDj,sdt.TnPriceDj,sdt.TotalDj,sdt.OriginalPrice
,sdt.OriginalTnPrice,sdt.OriginalToTal,sdt.Price,sdt.TnPrice,sdt.ToTal
,[dbo].[fn_GetNowDiscount_YCXJD](sdt.PlanGUID,pr.BldGUID) AS YCXJD
,[dbo].[fn_GetNowDiscount_JDBL](sdt.PlanGUID) AS ASYHJD
,[dbo].[fn_GetNowDiscount_BCPointAmount](sdt.PlanGUID,pr.BldGUID,'BCPoint') AS CXJD
,[dbo].[fn_GetNowDiscount_BCPointAmount](sdt.PlanGUID,pr.BldGUID,'BCAmount') AS CXJE
--（标准总价-促销优惠（金额））*（1-一次性付款优惠-按时签约优惠-促销优惠减点）
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

DECLARE @ProjGUID AS varchar(40)	--一级项目GUID
DECLARE @ParentCode AS varchar(40)  --一级项目ProjCode

--调价方案在一级项目
SELECT @ProjGUID=ProjGUID
FROM s_TjTjPlan 
WHERE TjPlanGUID=@PlanGUID

SELECT @ParentCode = ProjCode
FROM p_project
WHERE ProjGUID=@ProjGUID



--生成前，先删除【本次拟报资源表】、【项目货值表】、【业态货值表】、【楼栋货值表】、
--【楼栋信息分析表】、【批次信息分析表】、【价格异常房间表】、【试算房间明细表】
--生成后，刷新4个页签的所有列表
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
--WHERE dd.table_name_c='价格异常房间表'

--SELECT * FROM myAction 
--WHERE ObjectType='01010109'

--是否导入模板
IF EXISTS(SELECT 1 FROM s_TjTjResult WHERE TjPlanGUID=@PlanGUID)
BEGIN
	PRINT '已导入价格'

--生成本次报价资源情况-C1（本次导入的房间范围）
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

--------------[进入本次修改区域:2014-09-11]-------------

--1.1----------------------------------------------------
--生成项目货值(面积)-C2
declare @TargetBJArea_Proj_Area as decimal(23,4)=0.0000
declare @TargetDTArea_Proj_Area as decimal(23,4)=0.0000
declare @TZQDT_Proj_Area as decimal(23,4)=0.0000
declare @YTYS_Proj_Area as decimal(23,4)=0.0000
declare @YTWS_Proj_Area as decimal(23,4)=0.0000
declare @BCBP_Proj_Area as decimal(23,4)=0.0000
declare @WTS_Proj_Area as decimal(23,4)=0.0000
declare @XJ_Proj_Area as decimal(23,4)=0.0000

--目标报建面积					
--TargetBJArea					
--当前一级项目下所有末级项目的销售楼栋在商业计划书表（ys_BusinessPlan）中
--对应的工程楼栋的KsArea可售面积
select @TargetBJArea_Proj_Area=isnull(sum(isnull(gcb.KsArea,0)),0)
FROM dbo.jd_GCBuilding gcb 
where gcb.ProjGUID in (
SELECT ProjGUID FROM p_project WHERE ParentCode=@ParentCode
)

--目标动态面积
--TargetDTArea
--当前一级项目下所有未推售的工程楼栋取工程楼栋表中的KsArea可售面积
--+一级项目下所有已推售楼栋所有房间预售面积（P_ROOM.YsBldArea）之和
select @TargetDTArea_Proj_Area = isnull(sum(isnull(dbo.fn_CalcBldValue_Tjf(gcb.BldGUID,'targetdtarea',@PlanGUID),0)),0)
FROM dbo.jd_GCBuilding gcb 
where gcb.ProjGUID in (
SELECT ProjGUID FROM p_project WHERE ParentCode=@ParentCode
)



--调整前动态值
--TZQDT
--当前一级项目下所有未推售未推售的工程楼栋取工程楼栋表中的KsArea可售面积
--+一级项目下所有已推售楼栋所有房间最新建筑面积之和（有实测面积的取实测面积（ScBldArea），实测为0的取预售面积）													
select @TZQDT_Proj_Area = isnull(sum(isnull(dbo.fn_CalcBldValue_Tjf(gcb.BldGUID,'tzqdt',@PlanGUID),0)),0)
FROM dbo.jd_GCBuilding gcb 
where gcb.ProjGUID in (
SELECT ProjGUID FROM p_project WHERE ParentCode=@ParentCode
)

--已推已售					
--YTYS
--当前一级项目下所有已推已售的房间在房间表的ScBldArea合计，如ScBldArea为0则取该房间的YsBldArea													
select @YTYS_Proj_Area= isnull(sum(isnull(dbo.fn_CalcBldValue_Tjf(gcb.BldGUID,'ytys_area',@PlanGUID),0)),0)
FROM dbo.jd_GCBuilding gcb 
where gcb.ProjGUID in (
SELECT ProjGUID FROM p_project WHERE ParentCode=@ParentCode
)

--已推未售
--YTWS
--当前一级项目已推楼栋下除本次报批外的 所有已推未售的房间在房间表的ScBldArea合计，如ScBldArea为0则取该房间的YsBldArea
select @YTWS_Proj_Area=isnull(sum( case when isnull(ScBldArea,0)=0 then isnull(YsBldArea,0) else isnull(ScBldArea,0) end  ),0)
from p_room
where BldGUID in 
(

	select pb.BldGUID
	FROM p_Building pb 
	where pb.ProjGUID in (
	SELECT ProjGUID FROM p_project WHERE ParentCode=@ParentCode
	) 
	AND  --已推楼栋
	(
	Not EXISTS(SELECT 1 FROM p_room WHERE BldGUID=pb.BldGUID AND TotalDj=0)
	AND 
	EXISTS(SELECT 1 FROM p_room WHERE BldGUID=pb.BldGUID)
	)
	and pb.IsBld=1
)
and RoomGUID not in (select RoomGUID from s_TjTjResult where TjPlanGUID=@PlanGUID)
and NOT EXISTS(SELECT 1 FROM s_trade WHERE RoomGUID=p_room.RoomGUID AND TradeStatus='激活')
AND Status NOT IN ('认购','签约')

--本次报批
--BCBP
--s_TjTjResult表的房间的ScBldArea合计，如ScBldArea为0则取该房间的YsBldArea													
select @BCBP_Proj_Area=isnull(sum( case when isnull(pr.ScBldArea,0)=0 then isnull(pr.YsBldArea,0) else isnull(pr.ScBldArea,0) end  ) ,0)
from s_TjTjResult sdt left join p_room pr
on sdt.RoomGUID=pr.RoomGUID
where sdt.TjPlanGUID=@PlanGUID



--未推售
--WTS
--孙瑞增加[加上未引入的即可]
SELECT @WTS_Proj_Area=ISNULL(SUM(gcb.KsArea),0.00)
FROM dbo.jd_GCBuilding  gcb
--未被引用的楼栋
WHERE gcb.BldFullCode NOT IN
(
	SELECT p_Building.ParentCode + '.' + p_Building.BldCode
	FROM dbo.p_Project
	INNER JOIN dbo.p_Building ON dbo.p_Building.ProjGUID = dbo.p_Project.ProjGUID
	WHERE p_Project.ParentCode=@ParentCode	--一级项目的子项目code
)
AND gcb.ProjGUID IN
(
	SELECT ProjGUID FROM dbo.p_Project WHERE ParentCode=@ParentCode
)
SELECT @WTS_Proj_Area=@WTS_Proj_Area+ISNULL(SUM(gcb.KsArea),0.00)
FROM dbo.jd_GCBuilding  gcb
--被引用的楼栋,无房间
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
--被引用，有房间，但是底总价之和0
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
	--这里取本次报批的房间
	SELECT pbld.ParentCode + '.' + pbld.BldCode
	FROM dbo.s_TjTjResult
	INNER join p_Room pr ON pr.RoomGUID=dbo.s_TjTjResult.RoomGUID
	INNER JOIN dbo.p_Building pbld ON pbld.BldGUID = pr.BldGUID
)
--End Of 孙瑞添加

--小计
--XJ
--已推已售+已推未售+本次报批+未推售
set @XJ_Proj_Area = @YTYS_Proj_Area+@YTWS_Proj_Area+@BCBP_Proj_Area+@WTS_Proj_Area


insert into s_DjTjProjValue(DjTjProjValueGUID,PlanGUID
,TargetBJArea,TargetDTArea
,TZQDT,YTYS,YTWS,BCBP,WTS,XJ
,Sort,ProjGUID)
select dbo.SeqNewId() as DjTjProjValueGUID,@PlanGUID
,@TargetBJArea_Proj_Area,@TargetDTArea_Proj_Area
,@TZQDT_Proj_Area,@YTYS_Proj_Area,@YTWS_Proj_Area,@BCBP_Proj_Area,@WTS_Proj_Area,@XJ_Proj_Area
,1,@ProjGUID



-----------以上代码,完成时间:2014年9月11日20:11:23
--1.2----------------------------------------------------
--生成项目货值(金额)-C2
declare @TargetBJArea_Proj_Hz as decimal(23,4)=0.0000
declare @TargetDTArea_Proj_Hz as decimal(23,4)=0.0000
declare @TZQDT_Proj_Hz as decimal(23,4)=0.0000
declare @YTYS_Proj_Hz as decimal(23,4)=0.0000
declare @YTWS_Proj_Hz as decimal(23,4)=0.0000
declare @BCBP_Proj_Hz as decimal(23,4)=0.0000
declare @WTS_Proj_Hz as decimal(23,4)=0.0000
declare @XJ_Proj_Hz as decimal(23,4)=0.0000

--目标报建面积					
--TargetBJArea					
--当前一级项目下所有末级项目的销售楼栋在商业计划书表（ys_BusinessPlan）中
--对应的最新版本的每个预算楼栋的基准目标总价（ys_BusinessPlanDtl.TotalAmount）合计
select @TargetBJArea_Proj_Area=isnull(sum(isnull(gcb.YSMBTotle,0)),0)
FROM dbo.jd_GCBuilding gcb 
where gcb.ProjGUID in (
SELECT ProjGUID FROM p_project WHERE ParentCode=@ParentCode
)

--目标动态面积
--TargetDTArea
--当前一级项目下所有未推售的取商业计划书中最新版本所有楼栋的基准目标总价之和
--+已推售楼栋下所有房间的商业计划分户总价p_room.PlanTotal之和

select @TargetDTArea_Proj_Area = isnull(sum(isnull(dbo.fn_CalcBldValue_Tjf(gcb.BldGUID,'targetdtarea_hz',@PlanGUID),0)),0)
FROM dbo.jd_GCBuilding gcb 
where gcb.ProjGUID in (
SELECT ProjGUID FROM p_project WHERE ParentCode=@ParentCode
)


--调整前动态值
--TZQDT
--当前一级项目下所有已推已售房间总价合计
--+所有已推未售房间总价合计
--+未推售的工程楼栋YSMBTotle
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
	AND --已推楼栋
	(
	Not EXISTS(SELECT 1 FROM p_room WHERE BldGUID=pb.BldGUID AND TotalDj=0)
	AND 
	EXISTS(SELECT 1 FROM p_room WHERE BldGUID=pb.BldGUID)
	)
	and pb.IsBld=1
)
AND EXISTS(SELECT 1 FROM s_trade WHERE RoomGUID=pr.RoomGUID AND TradeStatus='激活')
AND pr.Status IN ('认购','签约')

select @TZQDT_Proj_Hz = @TZQDT_Proj_Hz + isnull(sum(ISNULL([dbo].[fn_GetRoomYTWS](pr.RoomGUID),0)),0)
from p_room pr 
where BldGUID in 
(
	select BldGUID
	FROM p_Building pb 
	where pb.ProjGUID in (
	SELECT ProjGUID FROM p_project WHERE ParentCode=@ParentCode
	) 
	AND --已推楼栋
	(
	Not EXISTS(SELECT 1 FROM p_room WHERE BldGUID=pb.BldGUID AND TotalDj=0)
	AND 
	EXISTS(SELECT 1 FROM p_room WHERE BldGUID=pb.BldGUID)
	)
	and pb.IsBld=1
)
AND NOT EXISTS(SELECT 1 FROM s_trade WHERE RoomGUID=pr.RoomGUID AND TradeStatus='激活')
AND pr.Status NOT IN ('认购','签约')

select @TZQDT_Proj_Hz = @TZQDT_Proj_Hz + isnull(sum(ISNULL([dbo].[fn_CalcBldValue_Tjf](gcb.BldGUID,'tzqdt_hz',@PlanGUID),0)),0)
FROM dbo.jd_GCBuilding gcb 
where gcb.ProjGUID in (
SELECT ProjGUID FROM p_project WHERE ParentCode=@ParentCode
)



--已推已售					
--YTYS
--当前一级项目下所有已推已售房间总价合计
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
	AND --已推楼栋
	(
	Not EXISTS(SELECT 1 FROM p_room WHERE BldGUID=pb.BldGUID AND TotalDj=0)
	AND 
	EXISTS(SELECT 1 FROM p_room WHERE BldGUID=pb.BldGUID)
	)
	and pb.IsBld=1
)
AND EXISTS(SELECT 1 FROM s_trade WHERE RoomGUID=pr.RoomGUID AND TradeStatus='激活')
AND pr.Status IN ('认购','签约')

--已推未售
--YTWS
--当前一级项目下除本次报批房间外的所有已推未售房间的底价总价合计
select @YTWS_Proj_Hz=isnull(sum(ISNULL([dbo].[fn_GetRoomYTWS](RoomGUID),0)),0)
from p_room
where BldGUID in 
(

	select pb.BldGUID
	FROM p_Building pb 
	where pb.ProjGUID in (
	SELECT ProjGUID FROM p_project WHERE ParentCode=@ParentCode
	) 
	and	--已推楼栋
	(
	Not EXISTS(SELECT 1 FROM p_room WHERE BldGUID=pb.BldGUID AND TotalDj=0)
	AND 
	EXISTS(SELECT 1 FROM p_room WHERE BldGUID=pb.BldGUID)
	)
	and pb.IsBld=1
)
and RoomGUID not in (select RoomGUID from s_TjTjResult where TjPlanGUID=@PlanGUID)
and NOT EXISTS(SELECT 1 FROM s_trade WHERE RoomGUID=p_room.RoomGUID AND TradeStatus='激活')
AND Status NOT IN ('认购','签约')

--本次报批
--BCBP
--s_TjTjResult表的房间的底价总价TotalDj合计												
select @BCBP_Proj_Hz=isnull(sum( isnull(sdt.TotalDj,0)) ,0)
from s_TjTjResult sdt 
where sdt.TjPlanGUID=@PlanGUID

--未推售
--WTS
--孙瑞增加[加上未引入的即可]
SELECT @WTS_Proj_Hz=ISNULL(SUM(gcb.YSMBTotle),0.00)
FROM dbo.jd_GCBuilding  gcb
--未被引用的楼栋
WHERE gcb.BldFullCode NOT IN
(
	SELECT p_Building.ParentCode + '.' + p_Building.BldCode
	FROM dbo.p_Project
	INNER JOIN dbo.p_Building ON dbo.p_Building.ProjGUID = dbo.p_Project.ProjGUID
	WHERE p_Project.ParentCode=@ParentCode	--一级项目的子项目code
)
AND gcb.ProjGUID IN
(
	SELECT ProjGUID FROM dbo.p_Project WHERE ParentCode=@ParentCode
)
SELECT @WTS_Proj_Hz=@WTS_Proj_Hz+ISNULL(SUM(gcb.YSMBTotle),0.00)
FROM dbo.jd_GCBuilding  gcb
--被引用的楼栋,无房间
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
--被引用，有房间，但是底总价之和0
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
	--这里取本次报批的房间
	SELECT pbld.ParentCode + '.' + pbld.BldCode
	FROM dbo.s_TjTjResult
	INNER join p_Room pr ON pr.RoomGUID=dbo.s_TjTjResult.RoomGUID
	INNER JOIN dbo.p_Building pbld ON pbld.BldGUID = pr.BldGUID
)
--End Of 孙瑞添加

--小计
--XJ
--已推已售+已推未售+本次报批+未推售
set @XJ_Proj_Hz = @YTYS_Proj_Hz+@YTWS_Proj_Hz+@BCBP_Proj_Hz+@WTS_Proj_Hz

insert into s_DjTjProjValue(DjTjProjValueGUID,PlanGUID
,TargetBJArea,TargetDTArea
,TZQDT,YTYS,YTWS,BCBP,WTS,XJ
,Sort,ProjGUID)
select dbo.SeqNewId() as DjTjProjValueGUID,@PlanGUID
,@TargetBJArea_Proj_Hz,@TargetDTArea_Proj_Hz
,@TZQDT_Proj_Hz,@YTYS_Proj_Hz,@YTWS_Proj_Hz,@BCBP_Proj_Hz,@WTS_Proj_Hz,@XJ_Proj_Hz
,2,@ProjGUID



---------以上，完成：2014年9月11日20:48:26
--1.3.1---------------------------------------------------
--生成楼栋货值（面积）-C3

--TargetBJArea
--销售楼栋在商业计划书表（ys_BusinessPlan）中对应的最新版本的预算楼栋的建筑面积（ys_BusinessPlanDtl.BldArea）
--TargetDTArea
--楼栋未推售取商业计划书中最新版本的楼栋建筑面积,楼栋已推售取楼栋下所有房间预售面积之和p_room.YsBldArea
--TZQDT
--楼栋未推售取商业计划书中最新版本的楼栋建筑面积
--楼栋已推售取楼栋下所有房间实测面积p_room.ScBldArea之和（实测面积为0取房间的预售面积）
--YTYS
--楼栋下所有已推已售的房间在房间表的ScBldArea合计，如ScBldArea为0则取该房间的YsBldArea
--YTWS
--楼栋下除本次报批外的所有已推未售的房间在房间表的ScBldArea合计，如ScBldArea为0则取该房间的YsBldArea

--BCBP
--s_TjTjResult表的房间的ScBldArea合计，如ScBldArea为0则取该房间的YsBldArea
--WTS
--楼栋未推售且不在本次报批内，取商业计划书中最新版本的楼栋建筑面积(设计确认就是0)
--楼栋已推售取0
--XJ
--已推已售+已推未售+本次报批+未推售

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
--将WTS的值，根据工程楼栋关联到销售楼栋
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
--生成楼栋货值（货值）-C3
--TargetBJArea
--销售楼栋在商业计划书表（ys_BusinessPlan）中对应的最新版本的预算楼栋的基准目标总价（ys_BusinessPlanDtl.TotalAmount）
--TargetDTArea
--楼栋未推售取商业计划书中最新版本的楼栋基准目标总价
--楼栋已推售取楼栋下所有房间商业计划总价p_room.PlanTotal
--TZQDT
--楼栋未推售取商业计划书中最新版本的楼栋基准目标总价
--楼栋已推售取楼栋下所有已推已售的房间总价合计+已推未售的房间总价合计
--YTYS
--楼栋下所有已推已售的房间总价合计
--YTWS
--楼栋下除本次报批外的所有已推未售的房间总价合计

--BCBP
--s_TjTjResult表的房间的底价总价TotalDj合计
--WTS
--楼栋未推售且不在本次报批内，取商业计划书中最新版本的楼栋基准目标总价(设计确认就是0)
--楼栋已推售取0
--XJ
--已推已售+已推未售+本次报批+未推售

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
,dbo.[fn_GetYtNameFromBld](gcb.BldGUID,'gcbuilding') as YTName  --数据引自p_BuildProductType（level=2）
into #tempC3_Hz
FROM dbo.jd_GCBuilding gcb
where gcb.ProjGUID in (
SELECT ProjGUID FROM p_project WHERE ParentCode=@ParentCode
)


--******sunsoft area************
--将WTS的值，根据工程楼栋关联到销售楼栋
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
--生成楼栋货值（均价）-C3

--楼栋的货值/面积
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
--生成业态货值（面积）-C4
--汇总一级项目的该业态下所有楼栋的对应指标合计

--业态(cb_HkbProductWork.ProductGUID)引自 产品类型(cb_HkbProductWork.ProductName,cb_HkbProductWork.BProductTypeCode)，
--所以多个业态可以挂在同一个产品类型下

select 
( SELECT top 1 BuildProductTypeGUID FROM p_BuildProductType WHERE LEVEL=2 and BProductTypeShortName=#tempC3_Area.YTName ) as YTGUID  --level2下不会重复
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
--生成业态货值（货值）-C4
--汇总一级项目的该业态下所有楼栋的对应指标合计
select 
--ProductGUID as YTGUID
( SELECT top 1 BuildProductTypeGUID FROM p_BuildProductType WHERE LEVEL=2 and BProductTypeShortName=#tempC3_Hz.YTName ) as YTGUID  --level2下不会重复
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
--生成业态货值（均价）-C4
--业态的货值/面积
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
--生成楼栋信息分析-C5
--Ts:以楼栋维度汇总s_TjTjResult表中每个楼栋下本次上报的房间套数
--BldArea:以楼栋维度汇总s_TjTjResult表中每个楼栋下本次上报的房间在房间表的实测建筑面积p_room.ScBldArea（实测为0取预售建筑面积YsBldArea）
--ZTs:以楼栋维度汇总每个楼栋房间套数
--ZBldArea:以楼栋维度汇总每个楼栋下所有房间在房间表的预售建筑面积p_room.YsBldArea
--BuAmount:取商业计划书中最新版本的楼栋基准目标单价ys_BusinessPlanDtl.Amount
--BuTotle:取商业计划书中最新版本的楼栋基准目标总价ys_BusinessPlanDtl.TotalAmount
--FHAmount:取楼栋中本次上报的房源的商业计划分户总价之和s_TjTjResult.TotalBu/对应房间的预售面积p_room.Ysbldarea之和
--FHTotle:取楼栋中本次上报的房源的商业计划分户总价s_TjTjResult.TotalBu合计
--HTAmount:楼栋下所有已推已售的房间总价合计/房间的实测建筑面积合计p_room.ScBldArea（实测面积为0取预售建筑面积）
--HTTotle:楼栋下所有已推已售的房间总价合计
--RecentlyAmount:取楼栋中所有房间在房间表的底价总价p_room.TotleDj合计（房间存在有效特价时当前系统时间在特价生效和失效日期间，取TotalTj）
--/对应房间实测建筑面积p_room.ScBldArea之和（实测为0取预售）
--RecentlyTotle:取楼栋中所有房间在房间表的底价总价p_room.TotleDj合计（房间存在有效特价时当前系统时间在特价生效和失效日期间，取TotalTj）
--BCRecentlyAmount:取楼栋中（本次未上报的房间在房间表底价总价p_room.TotleDj合计+本次调整房间在s_TjTjResult底价总价TotleDj合计）
--/对应房间实测建筑面积p_room.ScBldArea之和（无实测取预售）
--BCRecentlyTotle:取楼栋中本次未上报的房间在房间表底价总价+本次调整房间在s_TjTjResult底价总价

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
--HTAmount:楼栋下所有已推已售的房间总价合计/房间的实测建筑面积合计p_room.ScBldArea（实测面积为0取预售建筑面积）
,(case when isnull(b.HTTotleAreaSum,0)=0 then 0 else round( isnull(b.HTTotle,0)*1.0/b.HTTotleAreaSum,4) end) as HTAmount
,b.HTTotle
,(case when isnull(b.ScYsBldArea,0)=0 then 0 else round( isnull(b.RecentlyTotle,0)*1.0/b.ScYsBldArea,4) end) as RecentlyAmount
,b.RecentlyTotle
--BCRecentlyAmount:取楼栋中（本次未上报的房间在房间表底价总价(按特价房逻辑取数)合计+本次调整房间在s_TjTjResult底价总价TotleDj合计）
--/对应房间实测建筑面积p_room.ScBldArea之和（无实测取预售）
,(case when isnull(b.ScYsBldArea,0)=0 then 0 else round( (isnull(c.BCRecentlyTotle_WSB,0)+isnull(a.BCRecentlyTotle_BCTZ,0))*1.0/b.ScYsBldArea,4) end) as BCRecentlyAmount
--BCRecentlyTotle:取楼栋中本次未上报的房间在房间表底价总价+本次调整房间在s_TjTjResult底价总价
,(isnull(c.BCRecentlyTotle_WSB,0)+isnull(a.BCRecentlyTotle_BCTZ,0)) as BCRecentlyTotle
--,isnull(c.BCRecentlyTotle_WSB,0),isnull(a.BCRecentlyTotle_BCTZ,0)
from 
(
--楼栋下本次上报房间
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
--楼栋下所有房间
select pr.BldGUID
,count(1) as ZTs
,isnull(sum(isnull(pr.YsBldArea,0)),0) as ZBldArea
,isnull(sum(isnull([dbo].[fn_GetRoomTjfAmountSum](pr.RoomGUID),0)),0) as RecentlyTotle
,isnull(sum( case when isnull(pr.ScBldArea,0)=0 then isnull(pr.YsBldArea,0) else isnull(pr.ScBldArea,0) end  ) ,0) as ScYsBldArea
--HTTotle:楼栋下所有已推已售的房间总价合计
,ISNULL(sum(isnull(vsYTYS.YTYS,0)),0) as HTTotle
,isnull(sum(vsYTYS.ScYsAreaSum),0) as HTTotleAreaSum
from p_room pr left join vs_YTYS_View vsYTYS
on pr.RoomGUID=vsYTYS.RoomGUID 
where pr.BldGUID in (select BldGUID from s_TjTjResult where TjPlanGUID=@PlanGUID)
group by pr.BldGUID	
) b
on a.BldGUID=b.BldGUID
left join (
--楼栋下本次未上报房间
select BldGUID
,isnull(sum(isnull(dbo.[fn_GetRoomTjfAmountSum](RoomGUID),0)),0) as BCRecentlyTotle_WSB		--是否特价房
--BCRecentlyTotle:取楼栋中本次未上报的房间在房间表底价总价(按特价房逻辑取数BCRecentlyTotle_WSB)+本次调整房间在s_TjTjResult底价总价
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
	PRINT '未导入价格'
	
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
	IDType int,			--项目12，业态楼栋3
	type int,			--项目1，业态2，楼栋3
	YTName varchar(200),		--业态，楼栋	
	YTCode varchar(200),		--业态CODE
	BldCode varchar(200),		--楼栋CODE
	ShowType int,					--面积1，均价2，货值3
	IsHz int,						--是否货值(货值：数据库取出的金额/10000，保留4位小数)
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
--项目货值列表（项目可租售总面积行）:项目可租售总面积
--数据表：项目货值表
--过滤条件：方案GUID=本次方案GUID、排序=1
INSERT INTO #Show(
	IDType ,type ,YTName ,YTCode ,BldCode,ShowType,IsHz,TargetBJArea ,TargetDTArea ,
	TZQDT ,YTYS , YTWS , BCBP ,  WTS ,XJ ,DiffDt ,DiffBeAf ,IsXj
)
SELECT 1 AS IDType, 1 AS type,'项目可租售总面积' as YTName,'' AS YTCode,'' AS BldCode,1 AS ShowType,0 as IsHz
,TargetBJArea,TargetDTArea,TZQDT,YTYS,YTWS,BCBP,WTS,XJ
,(XJ-TargetDTArea) AS DiffDt ,(XJ-TZQDT) AS DiffBeAf,0
FROM s_DjTjProjValue
WHERE PlanGUID=@PlanGUID
AND Sort=1

--项目货值列表（项目总货值行）:项目总货值(万元)
INSERT INTO #Show(
	IDType ,type ,YTName ,YTCode ,BldCode,ShowType,IsHz,TargetBJArea ,TargetDTArea ,
	TZQDT ,YTYS , YTWS , BCBP ,  WTS ,XJ ,DiffDt ,DiffBeAf ,IsXj
)
SELECT 2 AS IDType,1 AS type,'项目总货值(万元)' as YTName,'' AS YTCode,'' AS BldCode,1 AS ShowType,1 as IsHz
,round(TargetBJArea/10000.0000,4),round(TargetDTArea/10000.0000,4),round(TZQDT/10000.0000,4),round(YTYS/10000.0000,4)
,round(YTWS/10000.0000,4),round(BCBP/10000.0000,4),round(WTS/10000.0000,4),round(XJ/10000.0000,4)
,(round(XJ/10000.0000,4)-round(TargetDTArea/10000.0000,4)) AS DiffDt ,(round(XJ/10000.0000,4)-round(TZQDT/10000.0000,4)) AS DiffBeAf
,0
FROM s_DjTjProjValue
WHERE PlanGUID=@PlanGUID
AND Sort=2

--2
--业态货值列表（面积行）
--数据表：业态货值表
--过滤条件：方案GUID=本次方案GUID、排序=1
--业态编码、排序升序
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


--业态货值列表（均价行）
--数据表：业态货值表
--过滤条件：方案GUID=本次方案GUID、排序=2"																					
--业态编码、排序升序	
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

--业态货值列表（货值行）
--数据表：业态货值表
--过滤条件：方案GUID=本次方案GUID、排序=3																					
--业态编码、排序升序
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
--楼栋货值列表（面积行）
--数据表：楼栋货值表
--过滤条件：方案GUID=本次方案GUID、排序=1
--楼栋编码、排序升序
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

--楼栋货值列表（均价行）
--数据表：楼栋货值表
--过滤条件：方案GUID=本次方案GUID、排序=2
--楼栋编码、排序升序
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

--楼栋货值列表（货值行）
--数据表：楼栋货值表
--过滤条件：方案GUID=本次方案GUID、排序=3
--楼栋编码、排序升序
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
	,@BldName=(CASE WHEN type IN (2) THEN '小计' when type in (3) then YTName ELSE  ''  end)
	,@ShowTypeName = (CASE WHEN type=1 THEN '' ELSE (CASE @ShowType WHEN 1 THEN '面积（m2）' WHEN 2 THEN '均价（元/m2）' when 3 then '货值（万元）' else '' end) end)
	,@rowspanYt = (CASE WHEN type= 1 then '1' 
				   else (SELECT count(1)+3 FROM #Init r WHERE r.YTCode=#Init.YTCode AND type=3  ) end ) --楼栋+小计行
	,@rowspanLd='3'		--楼栋3行
	,@colspan = (CASE WHEN type in (1) THEN '3' else '1' end)	--项目列合并3列
	,@rowspanYtNoLd = (CASE WHEN type in (1) THEN '1' else '3' end)	--不显示楼栋明细(只显示项目，业态小计)：项目单行，业态3行
	
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
,(CASE WHEN type IN (2) THEN '小计' when type in (3) then YTName ELSE  ''  end) as BldName
,(CASE WHEN type= 1 then '1' 
				   else (SELECT count(1)+1 FROM #Init r WHERE r.YTCode=#Init.YTCode AND type=3 ) end ) --楼栋+小计行
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




