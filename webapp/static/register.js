$(document).ready(function(){
  jsonAjaxForm('#registrationForm', 'POST', '/api/user_account', function(){
    if($("#email").val())
      $("#confirmationForm").removeClass("hidden");
    else
      $("#okAlert").removeClass("hidden");
  });
  jsonAjaxForm('#confirmationForm', 'PATCH', '/api/user_account', function(){
    $("#okAlert").removeClass("hidden");
  });
});
