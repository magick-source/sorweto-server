$(document).ready(function() {
  $('.cookie-consent .consent-ok').click(function() {
      $.get('/api/cookie/consent');
      $('.cookie-consent').hide();
    });
});
