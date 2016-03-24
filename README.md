###  About this package

Infinite scrolling is a very tricky area. Different packages solve problems of infinite scroll in
different ways, this package uses its own way.

### Description

**Scroller** is an [angular.js 1](https://angularjs.org/) directive. It is used much like ngRepeat
directive: every element of collection instantiates a template. Unlike ngRepeat, data source is a
function that can load data in small parts when needed. Also, ngRepeat watches for content changes
while Scroller assumes data in collection is never changed (items can only be added on both sides
of collection).

### Usage

Include minified scroller file in your template:

```html
    <script src="/bower_components/angular-infinite-scroller/dist/scroller.min.js" type="text/javascript"></script>
```

or full version:

```html
    <script src="/bower_components/angular-infinite-scroller/dist/scroller.js" type="text/javascript"></script>
```

List module 'scroller' in your app module dependencies:
```javascript
    var myApp = angular.module('myApp', ['scroller', ...]);
```

Now you can use directives:

```html
<ANY scroller-viewport="getData" scroller-settings="scrollerSettings" style="height: 500px">
    <ANY scroller-item>{{scrIndex}} {{scrData}}</ANY>
</ANY>
```

`scroller-viewport` is a directive that manages data: it measures scroll position inside of bound
element and makes decision to render or delete new items at the beginning or at the end of
rendered range. It adds state data to scope:

* `scrLoadingTop`: true if current request for top data is active.
* `scrReachedTop`: true if top of data is reached. Note that this state is temporary: after some
time viewport will drop this state and request top data once again. Timeout is configurable.
* `scrLoadingBottom`: like `scrLoadingTop` but for bottom data.
* `scrReachedBottom`: like `scrReachedTop` but for bottom data.

Next combinations of states are possible:

* `!loading & !reached`: possible during initialization, when no data is needed (enough data in
specified direction is loaded and boundary is not reached) or just after boundary timeout: for
example, top boundary was hit, after some timeout viewport will re-check top boundary and it first
drops top boundary flag and only after that it start new request for top data.
* `loading & !reached`: viewport needs more data and top boundary was not reached.
* `!loading & reached`: top boundary was reached.
* `loading & reached`: only possible if configuration changes. If `buffer.topBoundaryTimeout` or
`buffer.bottomBoundaryTimeout` changes to a bigger value it is possible that request for data is
performed and old boundary becomes valid again.

Scroller viewport height should be limited somehow or it will grow indefinitely.

`scroller-item` is a directive that is repeated for every rendered item. It adds item data to scope:

* `scrIndex`: `int`, index of current item
* `scrData`: data that was received from `getData` function

Note that contents of viewport may be arbitrary and scroller-item could be used several times:

```html
<div scroller-viewport="getData">
    <div class="numbers"><p scroller-item>{{scrIndex}}</p></div>
    <div class="text"><p scroller-item>{{scrData}}</p></div>
</div>
```

In this example both index and data will be rendered for every item. That is useful when you want to
render parts of your items in different parts of viewport.

`scroller-viewport` attribute can be complex object or just a function. Complex object should
contain:

* `initialIndex`: index of the element to start with
* `get`: `function(start, count, callback)`. This function is called whenever new data is
needed.

    * `start`: `int`
    * `count`: `int`
    * `callback`: `function(res)`. Callback should be called when needed data is ready.
        * `res`: `array`. Should contain `count` items in it. If request hit boundary of data, `res`
        can contain less then `count` data or even no data at all.

If `scroller-viewport` is just a `function`, `initialIndex` is considered to be 0.

During first stage, only initialIndex item and subsequent items will be rendered. When they fill
the whole viewport, rendering of top items will be allowed. This is done to improve user experience:
user will see same picture (initialIndex item on top of viewport) every single time. That will not
depend on what is loaded first: top items or bottom items.

### Known issues

Scroller does not intercept any events, so all the scrolling should work just like it is meant to
work in the operating system. However, elements far from shown area are deleted so keys like
pgUp/pgDown do not function properly. For example:

* user clicks in the scroller area
* user presses pgUp several times
* selected DOM Node is removed
* pgUp does not work anymore

### Dependencies

Scroller only requires angular.js. No need to install jQuery or other libraries.

### Development

If you want to dive into source code, compiled documentation can be found at
[github pages](https://slnpacifist.github.io/angular-infinite-scroller/docs/scroller.html)