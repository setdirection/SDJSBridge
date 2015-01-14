SDJSBridge
==========

Native/Hybrid Javascript Bridge

# JavaScript API

- Handler API - low-level API for registering and calling handlers.
- Platform API - API for native iOS features

## Handler API

The Handler API is contained in the `WebViewJavascriptBridge` namespace.

### registerHandler

Register a native handler.

**Parameters**

- `handlerName` (string) - Name of handler to register.
- `callback` (function(data)) - Callback function to execute when the handler is called.

**Example**

```
WebViewJavascriptBridge.registerHandler('customAlert', function (data) {
  var message = data.message;
  alert(message);
});
```

### callHandler

Call a native handler.

**Parameters**

- `handlerName` (string) - Name of handler
- `data` (object) - Parameters of handler
- `callback` (function(data)) - Callback function that is called after handler execution has finished.

**Example**

```
var options = {message: "Hello"};

WebViewJavascriptBridge.callHandler('customAlert', options, function (data) {

});
```

## Platform API
  
The Platform API is contained in the `SDJSPlatformAPI` namespace.

### info

Method returns platform information such as OS name, version, and API level.

**Input**

- `osName` (string) - OS name.
- `osVersion` (string) - OS version.
- `osName` (number) - Bridge API level supported by native platform.

**Example**

```
var info = SDJSPlatformAPI.info();

alert('bridge is running on ' + info.osName + ' ' + info.osVersion +
      '. Platform API v' + info.apiLevel);
```

### alert

Displays an alert with optional ok, cancel and neutral buttons.

**Input**

- `title` (string) - Title of alert view.
- `message` (string) - Message of alert view.
- `okButton` (string) - Title text of OK button.
- `cancelButton` (string) - Title text of Cancel button.
- `neutralButton` (string) - Title text of neutral button.

**Output**

- `action` (string)  - Value indicates the button that was pressed: “ok”, “cancel”, “neutral”.

**Example**

```
var options = {
    title: "hey!",
    message: "listen!",
    okButton: "OKAY",
    cancelButton: "CANCEL",
    neutralButton: "hmm..."
};

SDJSPlatformAPI.alert(options, function (action) {

});
```

### showLoadingIndicator

Show progress HUD.

**Input**

- `message` (string) - Message of progress HUD.

**Output**

No Callback.

**Example**

```
var options = {
    message: 'Loading...'
};

SDJSPlatformAPI.showLoadingIndicator(options);
```

### hideLoadingIndicator

Hide progress HUD.

**Input**

Null.

**Output**

No Callback.

### pushState

Push a new stack on to the navigation stack.

**Input**

- `title` (string) - Title view of view controller.
- `url` (string) - URL to push.
- `backTitle` (string) - Title of back button.

**Output**

No Callback.

**Example**

```
var options = {
  title: 'title page',
  url: 'example1.html'
};

SDJSPlatformAPI.pushState(options);
```

### replaceState

Replace current state on top of navigation stack.

**Input**

- `title` (string) - Title view of view controller.
- `url` (string) - URL to load.
- `backTitle` (string) - Title of back button.

**Output**

No Callback.

**Example**

```
var options = {
  title: 'title page',
  url: 'example2.html'
};

SDJSPlatformAPI.replaceState(options);
```

### webDialog

**Input**

- `title` (string) - Optional dialog title.
- `body` (string) - Includes html/css/javascript needed to render web page dialog.
- `okButton` (string) - Title text of OK button.
- `cancelButton` (string) - Title text of Cancel button.
- `neutralButton` (string) - Title text of neutral button.
- `handleAccept` (boolean) -  If true, tapping the positive button doesn’t close the dialog. Instead, it calls onAccept Javascript function that needs to be passed as part of body parameter.

**Output**

- `action` (string)  - Value indicates the button that was pressed: “ok”, “cancel”, “neutral”.
- `data` (string) -  An arbitrary string passed to close() function if the dialog is closed by Javascript code.

**Example**

```
var html =  '<h1>web dialog</h1><button onclick="JavaScript:closeDialog();">close</button>';

var options = {
    title: "Example Title",
    body: html,
    okButton: "Apply",
    cancelButton: "Cancel"
};

SDJSPlatformAPI.webDialog(options, function (data) {

});
```
