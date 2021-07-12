$('.swt-carousel').on('slide.bs.carousel', function (e) {
    
    var $e = $(e.relatedTarget);
    console.log( $e );
    
    $('.active, .active-next, .active-next2').addClass('sliding');

    var $next = $e.next(); 
    if ($next.length===0){
      $next = $('.carousel-item').eq(0);
    }
    
    var $nextnext = $next.next();
    if ($nextnext.length===0){
      $nextnext = $('.carousel-item').eq(0);
    }
    
    $e.removeClass('active-next');
    $next.removeClass('active-next2');

    $next.addClass('active-next');
    $nextnext.addClass('active-next2');
    
    setTimeout(function(){
        $(e).removeClass('sliding');
        $('.active, .active-next, .active-next2').removeClass('sliding');
    },1000);
    
});
