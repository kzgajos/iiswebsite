/**
  Library for inserting social media sharing buttons into our experiments.  

  See test.html in this directory for an example of how to incorporate this library in your own code.

  If you have declared the open graph properties (e.g., <meta property="og:title" content="Nutrition Test" />)
  the sharing library will read the values of those properties and there is almost nothing you need to do to configure
  the system.
  Here's how you can incorporate this code into your own test (in the <head> of your index.html):
 
 	<script src="media/share.js"></script>
    <script>
        $(function() {
            // For sharing on twitter it is good to have a short version of your URL; 
            // because it is not recorded among your open graph properties, it is good
            // to record it explicitly
            share.shorturl = "http://shar.es/1goMQI";
            // the makeButtons() method takes a CSS selector for DOM element(s) where the buttons
            // should be placed.  
            share.makeButtons(".share_this");
        });
    </script>

    Later in the code, once you have the participant ID you can call:
    share.participantID = participantID;

  The record of all sharing events is saved in the sharing_log database on labinthewild.org
*/

var share = {

	// debug level (0 = no debug messages)
    debug: 1,

    // if you set participant id, it will be recorded in the database when a sharing event is recorded
    // we assume that participant id is a positive integer
    participantID: null,

    // title of the experiment (for use with Twitter and LinkedIn)
	title: null,
    // short description of the experiment (needed by LinkedIn)
    description: null,
	// by default, set to the detected URL
	url: document.URL,
	// good to have a short URL for Twitter; by default set to the same value as the long URL
    // UPDATE: it looks like Twitter automatically shortens URLs so  no need to set it
	shorturl: document.URL,
    // URL of an image (needed for Pinterest)
    imageurl: null,

    // include twitter button?
	twitter: true,
    // include FB button?
	fb: true,
    // include LinkedIn button?
	linkedin: true,
    // incude Pinterest?
    pinterest: false,
    // include G+?
    gplus: false,
    // include Sina Weibo?
    sinaWeibo: false,

	// the server-side script to call to record a sharing event
    dataDestination: "http://www.labinthewild.org/share/share-data.php",

    // URLs of the social media icons
	twitterIcon: "http://www.labinthewild.org/share/images/twitter.png",
    fbIcon: "http://www.labinthewild.org/share/images/fb.png",
    linkedinIcon: "http://www.labinthewild.org/share/images/linkedin.png",
    pinterestIcon: "http://www.labinthewild.org/share/images/pinterest.png",
    gplusIcon: "http://www.labinthewild.org/share/images/gplus.png",
    sinaWeiboIcon: "http://www.labinthewild.org/share/images/weibo.png",

    // constants -- do not touch
    TWITTER: "twitter",
    FB: "fb",
    LINKEDIN: "LinkedIn",
    PINTEREST: "Pinterest",
    GPLUS: "G+",
    SINAWEIBO: "sinaWeibo",

    // generate the HTML containing share buttons and then put it inside all tags referred to by the selector
    makeButtons: function(selector) {
        this.title = this.title || $('meta[property="og:title"]').attr('content') 

		// place the buttons in the right place on the page
        var self = this;
		$(selector).each(function(i) {
            $(this).html(self.makeButtonsHelper(i));
        });

        // if sessionFlow tracking infrastructure is in place, make sure that the buttons are being tracked
        if (typeof sessionFlow != "undefined")
            sessionFlow.installListeners();
	},

    // creates a set of buttons, each with a unique id
    makeButtonsHelper: function(count) {
        var URItitle = encodeURIComponent(this.title);
        var URIdescription = encodeURIComponent(this.description || $('meta[property="og:description"]').attr('content'));
        var URIurl = encodeURIComponent(this.url || $('meta[property="og:url"]').attr('content'));
        var URIshorturl = encodeURIComponent(this.shorturl);
        var URIimageurl = encodeURIComponent(this.imageurl || $('meta[property="og:image"]').attr('content'));

        var buttons = "";

        if (this.twitter) {
            buttons += '<a class="sessionFlow" id="twitterShareButton' + count 
            + '" href="https://twitter.com/intent/tweet?text=' 
            + URItitle 
            + '&url=' + URIurl
            + '" target="_new" onclick="share.recordShare(\'' + this.TWITTER + '\')">'
            + '<img id="' + this.TWITTER + count + '" src="' + this.twitterIcon + '" width="50px" alt="share this paper on Twitter" /></a>\n';
        }

        if (this.fb) {
            buttons += '<a class="sessionFlow" id="fbShareButton' + count 
            + '" href="https://www.facebook.com/sharer/sharer.php?u=' + URIurl
            + '" target="_new" onclick="share.recordShare(\'' + this.FB + '\')">'
            + '<img id="' + this.FB + count + '" src="' + this.fbIcon + '" width="50px" alt="share this paper on Facebook" /></a>\n';
        }

        if (this.linkedin) {
            buttons += '<a class="sessionFlow" id="linkedinShareButton' + count 
            + '" href="https://www.linkedin.com/shareArticle?mini=true&url=' + URIurl
            + '&title=' + URItitle
            + '&summary=' + URIdescription
            + '" target="_new" onclick="share.recordShare(\'' + this.LINKEDIN + '\')">'
            + '<img id="' + this.LINKEDIN + count + '" src="' + this.linkedinIcon + '" width="50px" alt="share this paper on LinkedIn" /></a>\n';
        }

        if (this.pinterest) {
            buttons += '<a class="sessionFlow" id="pinterestShareButton' + count 
            + '" href="https://www.pinterest.com/pin/create/button/?url=' + URIurl
            + '&media=' + URIimageurl
            + '&description=' + URIdescription
            + '" target="_new" onclick="share.recordShare(\'' + this.PINTEREST + '\')">'
            + '<img id="' + this.PINTEREST + count + '" src="' + this.pinterestIcon + '" width="50px" alt="share this paper on Pinterest" /></a>\n';
        }

        if (this.gplus) {
            buttons += '<a class="sessionFlow" id="gplusShareButton' + count 
            + '" href="https://plus.google.com/share?url=' + URIurl
            + '" target="_new" onclick="share.recordShare(\'' + this.GPLUS + '\')">'
            + '<img id="' + this.GPLUS + count + '" src="' + this.gplusIcon + '" width="50px" alt="share this paper on Google+" /></a>\n';
        }

        if (this.sinaWeibo) {
            buttons += '<a class="sessionFlow" id="sinaWeiboShareButton' + count 
            + '" href="http://service.weibo.com/share/share.php?url=' + URIurl
            + '&title=' + URItitle 
            + '" target="_new" onclick="share.recordShare(\'' + this.SINAWEIBO + '\')">'
            + '<img id ="' + this.SINAWEIBO + count + '" src="' + this.sinaWeiboIcon + '" width="50px" alt="share this paper on Sina Weibo" /></a>\n';
        }

        return buttons;
    },

    // called when somebody clicked on the link to share; remember that if this function is as an event handler,
    // "this" will refer to the DOM element that was clicked and not to the share object.
    recordShare: function(destination) {
        console.log("Sharing " + this.title + " on " + destination + " by " + this.participantID);
        return false;

        data = {
            destination: destination,
            title: share.title,
            url: share.url,
            shorturl: share.shorturl,
            participantID: share.participantID
        };
        var dataJSON = JSON.stringify(data);
        $.ajax({
            url: share.dataDestination,
            type: "POST",
            data: {data: dataJSON},
            success: function( data ) {
                if (share.debug)
                    console.log("Sharing event recorded");
            },
            error: function() {
                if (share.debug)
                    console.log("Failed to transmit sharing event to server");
            }
        });

        return true;
    }


}