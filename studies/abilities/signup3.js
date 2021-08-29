/* Contains javascript for postsignup.shtml */


// checks if the user's browser is firefox
function checkFirefox()
{
	// check browser type
	var browser = navigator.userAgent.toLowerCase();
	
	if (browser.indexOf("firefox") != -1)
		document.getElementById("firefox").style.display = "none";

}