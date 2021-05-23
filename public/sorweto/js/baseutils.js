$('a.alert-close').click(function (ev) {
  ev.preventDefault();

  $(this).closest('.alert').hide();
});
