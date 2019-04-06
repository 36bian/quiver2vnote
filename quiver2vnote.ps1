<# 2019-4-6 17:17:00
脚本说明：
将quiver数据转换为vnotebook的数据格式

使用方法：
1. 修改源文件及目标文件路径后保存(21-22行)
2. 右键`使用Powershell运行`

注意事项：
1. 文件名含违禁字符的都处理了（详见57-60行）
2. 没有处理笔记之间的链接，东西少活累，自己碰到手动修改吧
3. 有极个别会报已存在，如果发现真的是缺失自己手动补齐
4. 后期请在软件内进行管理，直接操作数据本来就是件风险的事情

写作中遇到的坑：
1. .replace不是正则！只是字符串替换，我说怎么都没效果，浪费好几个钟头
2. 本来差不多了，发现还是报错，然后发现格式问题，于是才有的count计数判断首尾循环，做针对性处理
#>


$source_dir = "E:\Dropbox\Quiver.qvlibrary"
$output_dir_base = "E:\Users\Admin\Desktop\vnotebook_autocreate"

function main{
	Remove-Item $output_dir_base -recurse
	foreach($file in dir $source_dir *.qvnotebook){
		cd $file.fullname
		$note_name = (Get-Content meta.json | ConvertFrom-Json).name # 提取笔记本名称
		$output_dir = $output_dir_base+"\"+$note_name
		mkdir $output_dir # 生成目标文件夹
		create_meta($file)
		create_note($file)
	}
	cd $output_dir_base
	create_bigmeta # 生成笔记本元数据
	mkdir $output_dir_base\_v_recycle_bin # 生成回收站文件夹
}
# 生成笔记元数据
function create_meta($file){	
	# 文件头
	$vnote_json = @"
{
    "created_time": "2019-04-05T20:05:19Z",
    "files": [

"@
	# 文件中间
	$count = 1
	foreach ($file in dir meta.json -Recurse)  {
		$file_json = Get-Content $file.fullname | ConvertFrom-Json
		$created_time = Get-Date ([timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($file_json.created_at))) -uformat "%Y-%m-%dT%H:%M:%SZ"
		$modified_time = Get-Date ([timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($file_json.updated_at))) -uformat "%Y-%m-%dT%H:%M:%SZ"
		$name = $file_json.title
		
		if($name){ # 排除为空的meta
			# 替换特殊字符
			$name = $name.replace("|","or")
			$name = $name.replace("""","'")
			$name = $name.replace(":","：")
			$name = $name -replace('/|\\|>|<|\*|\?',"")
			$tags = $file_json.tags
			if ($count -gt 1){ # 中间的循环每次加上换行
				$vnote_json = $vnote_json + "`n"
			}
			$vnote_json = $vnote_json + @"
			{
				"attachment_folder": "",
				"attachments": [
				],
				"created_time": "$created_time",
				"modified_time": "$modified_time",
				"name": "$name.md",
				"tags": [
				]
			},
"@
			if($count -eq $((dir meta.json -Recurse).length)-1){ # 减一是因为有一个空的meta，最后一次循环就少一
				$vnote_json = $vnote_json.SubString(0,$vnote_json.Length-1)
			}
		}
		$count = $count + 1
	}
	# 文件尾
	$vnote_json = $vnote_json + @"

	],
    "sub_directories": [
    ],
    "version": "1"
}	
"@
	New-Item $output_dir\_vnote.json -value $vnote_json
}
# 生成笔记
function create_note($file){
	# 复制图片
	$allpic = dir *.png,*jpg,*gif -Recurse
	if($allpic){ # 图片不为空
		mkdir $output_dir\_v_images
		cp $allpic $output_dir\_v_images
	}
	# 创建文件
	foreach($file in dir content.json -Recurse){
		$file_json = Get-Content $file.fullname | ConvertFrom-Json
		$name = $file_json.title
		# 替换文件名特殊字符
		$name = $name.replace("|","or")
		$name = $name.replace("""","'")
		$name = $name.replace(":","：")
		$name = $name -replace('/|\\|>|<|\*|\?',"")
		# 替换图片路径
		$content = $file_json.cells[0].data
		$content = $content.replace("quiver-image-url","_v_images")
		$content = $content -replace(' =\d+x\d+',"") #他妹的，原来加杠才是正则
		New-Item $output_dir\$name".md" -value $content
	}
}
# 生成笔记本元数据
function create_bigmeta{
	# 文件头
	$vnote_json = @"
{
    "attachment_folder": "_v_attachments",
    "created_time": "2019-04-06T06:54:58Z",
    "files": [
    ],
    "image_folder": "",
    "recycle_bin_folder": "_v_recycle_bin",
    "sub_directories": [

"@
	# 文件中间
	$count = 1
	foreach($file in dir *){
		$dirname = $file.basename
		if ($count -gt 1){ # 中间的循环每次加上换行
			$vnote_json = $vnote_json + "`n"
		}
		$vnote_json = $vnote_json + @"
		{
            "name": "$dirname"
        },
"@
		if($count -eq $(dir *).length){ # 这里就不需要减一
			$vnote_json = $vnote_json.SubString(0,$vnote_json.Length-1)
		}
		$count = $count + 1
	}
	# 文件尾
	$vnote_json = $vnote_json + @"

    ],
    "tags": [
    ],
    "version": "1"
}
"@
	New-Item $output_dir_base\_vnote.json -value $vnote_json # 写入文件
}
main