<!--#include file="config.asp" -->
<%
try{
	pageCustomParams.tempModules.cache = require("cache");
	pageCustomParams.tempModules.dbo = require("DBO");
	pageCustomParams.tempModules.connect = require("openDataBase");
	pageCustomParams.tempModules.fns = require("fn");
	pageCustomParams.tempModules.tags = require("tags");
	pageCustomParams.tempCaches.globalCache = require("cache_global");
	
	if ( !pageCustomParams.tempCaches.globalCache.webstatus ){
		ConsoleClose("抱歉，网站暂时被关闭。");
	}
	
	if ( pageCustomParams.tempModules.connect !== true ){
		ConsoleClose("连接数据库失败");
	}
	
	require("status")();
	
	pageCustomParams.page = http.get("page");
	if ( pageCustomParams.page.length === 0 ){ 
		pageCustomParams.page = 1; 
	}else{
		if ( !isNaN( pageCustomParams.page ) ){
			pageCustomParams.page = Number(pageCustomParams.page);
			if ( pageCustomParams.page < 1 ){
				pageCustomParams.page = 1;
			}
		}else{
			ConsoleClose("page params error.");
		}
	};
	
	pageCustomParams.keyword = pageCustomParams.tempModules.fns.HTMLStr(pageCustomParams.tempModules.fns.SQLStr(http.form("keyword")));
	if (pageCustomParams.keyword.length === 0) {
		pageCustomParams.keyword = pageCustomParams.tempModules.fns.HTMLStr(pageCustomParams.tempModules.fns.SQLStr(http.get("keyword")));
	}
	pageCustomParams.keytype = pageCustomParams.tempModules.fns.HTMLStr(pageCustomParams.tempModules.fns.SQLStr(http.form("keytype") || "all")); //' all | title | content | tag
	
	if ( pageCustomParams.keyword.length === 0 ){
		ConsoleClose("非法参数");
	}
	
	if ( pageCustomParams.keytype.length === 0 ){
		keytype = "all";
	}
	
	if ( ["title", "content", "tag"].indexOf(pageCustomParams.keytype) === -1 ){
		pageCustomParams.keytype = "all";
	}
	
	if ( pageCustomParams.keyword.length === 0 ){
		ConsoleClose("关键字不能为空");
	}

	pageCustomParams.tempParams.category = require("cache_category");
	pageCustomParams.found = {
		keywords: pageCustomParams.keyword,
		types: pageCustomParams.keytype,
		lists: [],
		pages: []
	};
	
	function getCategoryName( id ){
		var rets = {},
			categoryJSON = pageCustomParams.tempParams.category;
			
		if ( categoryJSON[id + ""] !== undefined ){
			rets.id = id;
			rets.name = categoryJSON[id + ""].name;
			rets.info = categoryJSON[id + ""].info;
			rets.icon = "profile/icons/" + categoryJSON[id + ""].icon;
			rets.url = "default.asp?c=" + id;
		}
		
		return rets;
	}
	
	function getTags( tagStr ){
		var tagsCacheData = pageCustomParams.tempModules.tags,
			tagStrArrays = tagsCacheData.reFormatTags(tagStr),
			keeper = [];
				
		for ( var j = 0 ; j < tagStrArrays.length ; j++ ){
			var rets = tagsCacheData.readTagFromCache( Number(tagStrArrays[j]) );
			if ( rets !== undefined ){
				keeper.push({ 
					id: Number(tagStrArrays[j]), 
					name: rets.name,
					url: "tags.asp?id=" + tagStrArrays[j],
					count: rets.count
				});
			}
		}
		
		return keeper;
	}
	
	var getUserPhoto = pageCustomParams.tempModules.fns.getUserInfo;
	
	(function(dbo){
		var condition = " Where ";
		if ( pageCustomParams.keytype === "title" ){
			condition += "instr(log_title, '" +  pageCustomParams.keyword + "')";
		}else if ( pageCustomParams.keytype === "content" ){
			condition += "instr(log_content, '" +  pageCustomParams.keyword + "')";
		}else{
			condition += "instr(log_title, '" +  pageCustomParams.keyword + "') or instr(log_content, '" +  pageCustomParams.keyword + "')";
		}

		var totalSum = Number(String(config.conn.Execute("Select count(id) From blog_article" + condition)(0))),
			perpage = pageCustomParams.tempCaches.globalCache.articleperpagecount,
			_mod = 0,
			_pages = 0,
			totalPages = 0,
			sql = "";
			
		if ( totalSum === 0 ){
			return;
		}
			
		if ( totalSum < perpage ){ perpage = totalSum; }
		_mod = totalSum % perpage;
		_pages = Math.floor(totalSum / perpage);
		if ( _mod > 0 ){ totalPages = _pages + 1; }else{ totalPages = _pages; }
		if ( pageCustomParams.page > totalPages ){ pageCustomParams.page = totalPages;}
		
		if ( pageCustomParams.page > _pages ){
			sql = "Select top " + _mod + " * From blog_article" + condition + " Order By id ASC";
			sql = "Select * From (" + sql + ") Order By id DESC";
		}else{
			sql = "Select top " 
				+ (pageCustomParams.page * perpage) 
				+ " * From blog_article" + condition + " Order By id DESC";
			sql = "Select * From (Select top " + perpage + " * From (" + sql + ") Order By id) Order By id DESC";
		}

		dbo.trave({
			conn: config.conn,
			sql: sql,
			callback: function(){
				this.each(function(){
					pageCustomParams.found.lists.push({
						id: this("id").value,
						title: this("log_title").value,
						postDate: this("log_posttime").value,
						editDate: this("log_updatetime").value,
						category: getCategoryName(this("log_category").value),
						tags: getTags(this("log_tags").value),
						content: this("log_shortcontent").value,
						url: "article.asp?id=" + this("id").value,
						views: this("log_views").value,
						uid: getUserPhoto(this("log_uid").value),
						istop: this("log_istop").value,
						cover: this("log_cover").value,
						comments: this("log_comments").value
					});
				});
			}
		});
		
		pageCustomParams.tempParams.pages = pageCustomParams.tempModules.fns.pageAnalyze(pageCustomParams.page, totalPages);
		
		if ( 
			( pageCustomParams.found.lists.length > 0 ) && 
			( (pageCustomParams.tempParams.pages.to - pageCustomParams.tempParams.pages.from) > 0 ) 
		){
			for ( i = pageCustomParams.tempParams.pages.from ; i <= pageCustomParams.tempParams.pages.to ; i++ ){
				var url = "search.asp?keyword=" + escape(pageCustomParams.keyword) + "&page=" + i;
								
				if ( pageCustomParams.tempParams.pages.current === i ){
					pageCustomParams.found.pages.push({ key: i });
				}else{
					pageCustomParams.found.pages.push({ key: i, url : url });
				}				
			}
		}
	})(pageCustomParams.tempModules.dbo);
	
				
	delete pageCustomParams.tempCaches;
	delete pageCustomParams.tempModules;
	delete pageCustomParams.tempParams;
	
	include("profile/themes/" + pageCustomParams.global.theme + "/search.asp");
	CloseConnect();
}catch(e){
	ConsoleClose(e.message);
}
%>