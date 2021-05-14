$(document).ready(function() {
  $('.cookie-consent .consent-ok').click(function() {
      $.get('/api/cookie/consent');
      $('.cookie-consent').hide();
    });

  $('.cookie-consent .no-cookies').click(function() {
      window.location.assign( '/user/do-not-track' );
    });
});
