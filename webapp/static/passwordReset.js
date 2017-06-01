$(document).ready(function(){
  jsonAjaxForm('#requestForm', 'POST', '/api/user_account/passwordReset', function(){
    if($("#email").val())
      $("#confirmationForm").removeClass("hidden");
    else
      $("#okAlert").removeClass("hidden");
  });
  jsonAjaxForm('#confirmationForm', 'DELETE', '/api/user_account/passwordReset', function(){
    $("#okAlert").removeClass("hidden");
  });
});
