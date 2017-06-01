function jsonAjaxForm(selector, reqMethod, endpoint, afterSuccess) {
  $(selector).submit(function() {
    $(selector + ' > * > .submitBtn').prop('disabled', true);
    $.ajax({
      method: reqMethod,
      url: endpoint,
      data: $(selector).serializeJSON(),
      contentType: "application/json",
      success: function(res) {
        $(selector).hide();
        afterSuccess();
      },
      error: function(res) {
        $(selector + ' > .errAlert').text(res.responseJSON.error);
        $(selector + ' > .errAlert').removeClass('hidden');
        $(selector + ' > * > .submitBtn').prop('disabled', false);
      }
    });
    return false;
  });
}
