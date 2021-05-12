var fb_inited = 0;

window.fbAsyncInit = function() {
  FB.init({
    appId      : fb_app_id,
    cookie     : true,
    xfbml      : true,
    version    : 'v10.0'
  });

  fb_inited = 1;

  facebook_login();
};

function load_facebook(d, s, id) {
   var js, fjs = d.getElementsByTagName(s)[0];
   if (d.getElementById(id)) {return;}
   js = d.createElement(s); js.id = id;
   js.src = "https://connect.facebook.net/en_US/sdk.js";
   fjs.parentNode.insertBefore(js, fjs);
}

$(document).ready(function () {
  $('.facebook-login').click(function(){
    if ( ! fb_inited ) {
      load_facebook(document,'script', 'facebook-jssdk');
    } else {
      facebook_login();
    }
  });
});

function facebook_login() {
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
}

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

