var selectport = -1, selectports = [], ctrldown = false;

hash = function(s) {
    var hash = 0,
      i, char;
    if (s.length == 0) return hash;
    for (i = 0, l = s.length; i < l; i++) {
      char = s.charCodeAt(i);
	  if (
	  ((48<=char)&&(char<=57))||
	  ((1040<=char)&&(char<=1103))||
	  ((97<=char)&&(char<=122))||
	  ((65<=char)&&(char<=90))
	  )
      hash = ((hash << 5) - hash) + char;
      hash |= 0; // Convert to 32bit integer
    }
    return hash;
  };  
  
function refreshfunc() {
	var
		maintable = {};
	$('#maintable tr').each(function() {
	if (typeof($(this).attr("id")) != "undefined") {
		maintable[$(this).attr("id")]=[];
		maintable[$(this).attr("id")][0]=$(this).find('.nomer').html();
		maintable[$(this).attr("id")][1]=$(this).find('.state').html();
	}}); 
	
    $.ajax({
      type:"post",
      url:"get/mainmemo",
      data:{
		"filter":$("#input_at_cmd").val(),
		"port":selectport,
		"maintable":hash(JSON.stringify(maintable)),
	    "mainmemo":hash($("#mainmemo").val()),
	    "sendmemo":hash($("#sendmemo").val()),
	    "recvmemo":hash($("#recvmemo").val()),
	    "smsmemo":hash($("#smsmemo").val())
	  },
      datatype:"json",
      success:function(msg)
        {
          if (msg["mainmemo"]!==0) {
			$("#mainmemo").val(msg["mainmemo"]);
			$('#mainmemo').scrollTop(9999);
		  }
          if (msg["sendmemo"]!=0) {
			$("#sendmemo").val(msg["sendmemo"]);
		  }
          if (msg["recvmemo"]!=0) {
			$("#recvmemo").val(msg["recvmemo"]);   
		  }
		  if (msg["smsmemo"]!=0) {
			$("#smsmemo").val(msg["smsmemo"]);
		  }
          if (msg["maintable"]!=0) {
			  var jsonData = JSON.parse(msg["maintable"]);
				for (var counter in jsonData) {
					$("tr#"+counter).find('.nomer').html(jsonData[counter][0]);
					if (jsonData[counter][2]=="1") {
						//$("tr#"+counter).find('.nomer').css('color', 'red');
						$("tr#"+counter).children("td:first").css('background-color', '#768bdf');
					} else {
						//$("tr#"+counter).find('.nomer').css('color', 'black');
						$("tr#"+counter).children("td:first").css('background-color', '');
					}
					switch (true) {
						case jsonData[counter][1] == 100:
							$("tr#"+counter).find('.state').removeClass().addClass('state').addClass('alert-success').html(jsonData[counter][1]);
							break;
						case jsonData[counter][1] == 197:
							$("tr#"+counter).find('.state').removeClass().addClass('state').addClass('alert-warning').html(jsonData[counter][1]);
							break;							
						case jsonData[counter][1] == 198:
							$("tr#"+counter).find('.state').removeClass().addClass('state').addClass('alert-danger').html(jsonData[counter][1]);
							break;	
						case jsonData[counter][1] > 100:
							$("tr#"+counter).find('.state').removeClass().addClass('state').addClass('alert-info').html(jsonData[counter][1]);
							break;	
						case jsonData[counter][1] < 100:
							$("tr#"+counter).find('.state').removeClass().addClass('state').addClass('alert-danger').html(jsonData[counter][1]);
							break;
					}
				}
		  }
        },
		error: function (request, status, error) {
		clearInterval(refreshtimer);
		}
	});
}

$(document).keydown(function(e) {
    if(e.keyCode == 17) { 
	  ctrldown = true; 
	}
	if (e.keyCode == 67 && e.ctrlKey && $(':focus').length == 0) {
	    var $temp = $("<input>");
	    $("body").append($temp);
	    $temp.val($('tr#'+selectport + ' > td:nth-child(2) > div:nth-child(1)').html().replace(/^.{2}/, '')).select();
		if (selectport!=-1)
			document.execCommand("copy");
	    $temp.remove();
    }
    //e.preventDefault();
});

$(document).keyup(function(e) {
    if(e.keyCode == 17) { ctrldown = false; }
    //e.preventDefault();
});

$(document).ready(function() {
	refreshfunc();
	refreshtimer = setInterval(refreshfunc, 2500); 
	
$("#input_at_cmd").on('input', function() {
  refreshfunc();
});

$("#history_list").change(function(){
	var tmp = $(this).val();
	$("#history_text").val(tmp);
});

$('tr').dblclick(function(){
	var $temp = $("<input>");
	$("body").append($temp);
	$temp.val($('tr#'+selectport + ' > td:nth-child(2) > div:nth-child(1)').html().replace(/^.{2}/, '')).select();
	if (selectport!=-1)
		document.execCommand("copy");
	$temp.remove();
});

$("tr").click(function() {
	if (ctrldown) {
		if (selectports.indexOf($(this).attr("id")) == -1) {
			selectports.push($(this).attr("id"));
		}
		$(this).children("td:nth-child(2)").addClass('info');
	} else {
		selectports = [];
		selectports.push($(this).attr("id"));
		selectport = $(this).attr("id");
		$("#sendmemo").val("");
		$("#recvmemo").val("");
		$("#smsmemo").val("");
		$("tr").children("td:nth-child(2)").removeClass('info');
		$(this).children("td:nth-child(2)").addClass('info');
		$.ajax({
		type:"post",
		url:"get/port",
		data:{
			"id":selectport
		},
		datatype:"json",
		success:function(msg)
			{
			if (msg["result"]=="done") {
					refreshfunc();
					$('#history_list').find('option').remove();
					//$("#history_text").val("");
					for (var tmsg in msg["history"]) {
						//console.log(msg["history"][tmsg][0]);
						$('#history_list')
							.append($("<option></option>")
							.attr("value",msg["history"][tmsg][2])
							.attr("data-time",msg["history"][tmsg][1])
							.attr("data-otkogo",msg["history"][tmsg][0])
							.text(msg["history"][tmsg][1]+' '+msg["history"][tmsg][0])); 
					}
				}
			}
		});
	}
  });

$("#btn_system").click(function() {
	$("#system_div").toggle();
});
$("#btn_reset").click(function() {
	$(this).prop( "disabled", true );
	setTimeout(function() {$("#btn_reset").prop( "disabled", false );}, 3000);
	$.ajax({
		type:"post",
		url:"port/reset",
		data: "id="+encodeURIComponent(selectports.join()),
		datatype:"text"
	});
});
$("#btn_zapros_nomera").click(function() {
	$(this).prop( "disabled", true );
	setTimeout(function() {$("#btn_zapros_nomera").prop( "disabled", false );}, 500);
	if (ctrldown) {
		$.ajax({type:"post",
			url:"port/zaprosnomera2",
			data: "id="+encodeURIComponent(selectports.join()),
			datatype:"text"});
	} else {
	$.ajax({type:"post",
			url:"port/zaprosnomera",
			data: "id="+encodeURIComponent(selectports.join()),
			datatype:"text"});
	}
	/*if ($("#input_at_cmd").val()=='') {

	}
	else
	{
		$.ajax({
		type:"post",
		url:"port/setnomer",
		data:{
			"id":parseInt(selectport)+1,
			"nomer":$("#input_at_cmd").val()
			},
		datatype:"json",
		success:function(msg)
			{
			if (msg["cmd"]=="done") {
				}
			}
		});
	}*/
});

$("#btn_system_set_nomer").click(function() {
	$(this).prop( "disabled", true );
	setTimeout(function() {$("#btn_system_set_nomer").prop( "disabled", false );}, 500);
	if ($("#input_at_cmd").val()=='') {

	}
	else
	{
		$.ajax({
		type:"post",
		url:"port/setnomer",
		data:{
			"id":parseInt(selectport)+1,
			"nomer":$("#input_at_cmd").val()
			},
		datatype:"json",
		success:function(msg)
			{
			if (msg["cmd"]=="done") {
				}
			}
		});
	}
});

$("#btn_system_delete_sms").click(function() {
	$(this).prop( "disabled", true );
	setTimeout(function() {$("#btn_system_delete_sms").prop( "disabled", false );}, 250);
	if (($('#history_list option:selected').text()!='')&&(selectport!=-1))
	{
		$.ajax({
		type:"post",
		url:"port/delete_sms",
		data:{"id":selectport,"time":$('#history_list option:selected').attr("data-time"),"otkogo":$('#history_list option:selected').attr("data-otkogo"),"text":$('#history_list option:selected').val()},
		datatype:"json"
		});
	}
});

$("#btn_system_delete_service").click(function() {
	$(this).prop( "disabled", true );
	setTimeout(function() {$("#btn_system_delete_service").prop( "disabled", false );}, 250);
	$.ajax({
		type:"post",
		url:"port/delete_service",
		data: "id="+encodeURIComponent(selectports.join())+"&service="+encodeURIComponent($("#input_at_cmd").val()),
		datatype:"text"
		});
});

$("#btn_activ_nomera").click(function() {
	$(this).prop( "disabled", true );
	setTimeout(function() {$("#btn_activ_nomera").prop( "disabled", false );}, 500);
	$.ajax({
      type:"post",
      url:"port/activnomera",
      data:{"id":selectport},
      datatype:"json",
      success:function(msg)
        {
          if (msg["cmd"]=="done") {
            }
        }
	});
});

$("#btn_deactiv_nomera").click(function() {
	$(this).prop( "disabled", true );
	setTimeout(function() {$("#btn_deactiv_nomera").prop( "disabled", false );}, 500);
	$.ajax({
      type:"post",
      url:"port/deactivnomera",
      data:{"id":selectport},
      datatype:"json",
      success:function(msg)
        {
          if (msg["cmd"]=="done") {
            }
        }
	});
});

$("#btn_at_send").click(function() {
	$(this).prop( "disabled", true );
	setTimeout(function() {$("#btn_at_send").prop( "disabled", false );}, 250);
	$.ajax({
      type:"post",
      url:"port/sendatcmd",
      data:{"id":selectport,"cmd":$("#input_at_cmd").val()},
      datatype:"json",
      success:function(msg)
        {
          if (msg["cmd"]=="done") {
            }
        }
	});
});

$("#btn_send_sms").click(function() {
	$(this).prop( "disabled", true );
	setTimeout(function() {$("#btn_send_sms").prop( "disabled", false );}, 250);
	$.ajax({
      type:"post",
	  contentType: false,
      url:"port/sendsms",
	  processData:false,
      data: "id="+encodeURIComponent(selectports.join())+"&nomer="+encodeURIComponent($("#input_at_cmd").val())+"&text="+encodeURIComponent($("#history_text").val()),
      datatype:"text",
      success:function(msg)
        {
          if (msg["cmd"]=="done") {
            }
        }
	});
});

$("#btn_allsend_sms").click(function() {
	$(this).prop( "disabled", true );
	setTimeout(function() {$("#btn_allsend_sms").prop( "disabled", false );}, 250);
	$.ajax({
      type:"post",
	  contentType: false,
      url:"port/all_sendsms",
	  processData:false,
      data: "nomer="+encodeURIComponent($("#input_at_cmd").val())+"&text="+encodeURIComponent($("#history_text").val()),
      datatype:"text",
      success:function(msg)
        {
          if (msg["cmd"]=="done") {
            }
        }
	});
});

$("#btn_allsend_sms_noreg").click(function() {
	$(this).prop( "disabled", true );
	setTimeout(function() {$("#btn_allsend_sms_noreg").prop( "disabled", false );}, 250);
	$.ajax({
      type:"post",
	  contentType: false,
      url:"port/all_sendsms_noreg",
	  processData:false,
      data: "nomer="+encodeURIComponent($("#input_at_cmd").val())+"&text="+encodeURIComponent($("#history_text").val()),
      datatype:"text",
      success:function(msg)
        {
          if (msg["cmd"]=="done") {
            }
        }
	});
});

$("#btn_memoclear").click(function() {
	$(this).prop( "disabled", true );
	setTimeout(function() {$("#btn_memoclear").prop( "disabled", false );}, 1500);
	$("#mainmemo").val("");
	$.ajax({
      type:"post",
      url:"/main/memoclear",
      datatype:"json"
	});
});

$("#btn_systemreboot").click(function() {
	$(this).prop( "disabled", true );
	setTimeout(function() {$("#btn_systemreboot").prop( "disabled", false );}, 1500);
	$.ajax({
      type:"post",
      url:"/main/rebootsystem",
      datatype:"json"
	});
});

$("#btn_systemrestart").click(function() {
	$(this).prop( "disabled", true );
	setTimeout(function() {$("#btn_systemrestart").prop( "disabled", false );}, 1500);
	$.ajax({
      type:"post",
      url:"/main/restart",
      datatype:"json"
	});
});

$("#btn_systemexit").click(function() {
	$(this).prop( "disabled", true );
	setTimeout(function() {$("#btn_systemexit").prop( "disabled", false );}, 1500);
	$.ajax({
      type:"get",
      url:"/starter/exit",
      datatype:"json"
	});
});
$("#btn_allzapros").click(function() {
	$(this).prop( "disabled", true );
	setTimeout(function() {$("#btn_allzapros").prop( "disabled", false );}, 1500);
	$.ajax({
      type:"post",
      url:"/port/allzapros",
      datatype:"json"
	});
});
$("#btn_all_reset").click(function() {
	$(this).prop( "disabled", true );
	setTimeout(function() {$("#btn_all_reset").prop( "disabled", false );}, 1500);
	$.ajax({
      type:"post",
      url:"/port/allreset",
      datatype:"json"
	});
});
$("#btn_neopredelenzapros").click(function() {
	$(this).prop( "disabled", true );
	setTimeout(function() {$("#btn_neopredelenzapros").prop( "disabled", false );}, 1500);
	$.ajax({
      type:"post",
      url:"/port/neopredelenzapros",
      datatype:"json"
	});
});
$("#btn_reload_filter").click(function() {
	$(this).prop( "disabled", true );
	setTimeout(function() {$("#btn_reload_filter").prop( "disabled", false );}, 1500);
	$.ajax({
      type:"get",
      url:"/debug/reload",
      datatype:"json"
	});
});
//Кнопки debug и конфиг
$("#btn_system_config_filter").click(function() {
	$(this).prop( "disabled", true );
	setTimeout(function() {$("#btn_system_config_filter").prop( "disabled", false );}, 1500);
	window.open('/config/filter', '_blank', 'width=450, height=300');
});

$("#btn_system_config_telega").click(function() {
	$(this).prop( "disabled", true );
	setTimeout(function() {$("#btn_system_config_telega").prop( "disabled", false );}, 1500);
	window.open('/config/telegram', '_blank', 'width=450, height=300');
});

$("#btn_system_config_ports").click(function() {
	$(this).prop( "disabled", true );
	setTimeout(function() {$("#btn_system_config_ports").prop( "disabled", false );}, 1500);
	window.open('/config/ports', '_blank', 'width=450, height=300');
});

$("#btn_system_config_portsnomera").click(function() {
	$(this).prop( "disabled", true );
	setTimeout(function() {$("#btn_system_config_portsnomera").prop( "disabled", false );}, 1500);
	window.open('/config/portsnomera', '_blank', 'width=450, height=300');
});

$("#btn_system_config_url").click(function() {
	$(this).prop( "disabled", true );
	setTimeout(function() {$("#btn_system_config_url").prop( "disabled", false );}, 1500);
	window.open('/config/urlsms', '_blank', 'width=450, height=300');
});

$("#btn_system_config_triggers").click(function() {
	$(this).prop( "disabled", true );
	setTimeout(function() {$("#btn_system_config_triggers").prop( "disabled", false );}, 1500);
	window.open('/config/triggers', '_blank', 'width=450, height=300');
});

$("#btn_system_config_iin").click(function() {
	$(this).prop( "disabled", true );
	setTimeout(function() {$("#btn_system_config_iin").prop( "disabled", false );}, 1500);
	window.open('/config/iin', '_blank', 'width=600, height=300');
});

$("#btn_system_delete_service2").click(function() {
	$(this).prop( "disabled", true );
	setTimeout(function() {$("#btn_system_delete_service2").prop( "disabled", false );}, 1500);
	window.open('/config/delete_services', '_blank', 'width=450, height=300');
});

$("#btn_system_testsms").click(function() {
	$(this).prop( "disabled", true );
	setTimeout(function() {$("#btn_system_testsms").prop( "disabled", false );}, 1500);
	window.open('/debug/sendsms?id='+encodeURIComponent(selectports.join()), '_blank', 'width=420, height=180');
});


});