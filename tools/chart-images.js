var page = require('webpage').create();

function capture(page, url, callback) {
    page.onConsoleMessage = callback;
    page.open(url, function(status) { });
}

capture(page, "http://localhost:4567/", function(msg) {
    console.log(msg);
    capture(page, "http://localhost:4567/default", function(msg) {
	console.log(msg);
	page.open("http://localhost:4567/exit", function(status) {
	    phantom.exit();
	});
    });
});
