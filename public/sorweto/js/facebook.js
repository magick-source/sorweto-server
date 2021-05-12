//TODO(maybe): only init fb after the button was clicked?

window.fbAsyncInit = function() {
  FB.init({
    appId      : fb_app_id,
    cookie     : true,
    xfbml      : true,
    version    : 'v10.0'
  });

  FB.getLoginStatus(function(response) {
    if ( response.status == 'connected' ) {
      swt_login_with_facebook(response.authResponse);
    }
  });
};

(function(d, s, id){
   var js, fjs = d.getElementsByTagName(s)[0];
   if (d.getElementById(id)) {return;}
   js = d.createElement(s); js.id = id;
   js.src = "https://connect.facebook.net/en_US/sdk.js";
   fjs.parentNode.insertBefore(js, fjs);
 }(document, 'script', 'facebook-jssdk'));

$(document).ready(function () {
  $('.facebook-login').click(function(){ 
    FB.getLoginStatus(function(response) {
      if ( response.status == 'connected' ) {
        swt_login_with_facebook(response.authResponse);
      } else {
        FB.login(function(response){
          swt_login_with_facebook(response.authResponse);
        });
      }
    },{
        scope: 'public_profile,email'
    });
  });
});

function swt_login_with_facebook( response ) {
  url = sitevars.apibase + '/login/facebook';
  res =  $.post( url, response )
          .done( function( data ) {
              if ( data.done == 1 ) {
                window.location.assign( data.goto );
              }
            })
          .fail( function( jqXHR, err, errorThrown ) {
              var errorobj = {};
              // TODO(maybe): handle erros
            });
  
}

