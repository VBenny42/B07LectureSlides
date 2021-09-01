# the heck is SOLID

## let's not call it that

the acronym SOLID orders the principles confusingly. let's call it _LODIS_ instead.

## ok, the heck is LODIS

### first, terminology

- "X is a subtype of Y" means
  - If X is an `interface`, then Y is also an `interface`, and X `extends` Y
  - If X is a `class`, then
    - If Y is an `interface`, then X `implements` Y
    - If Y is a `class`, then X `extends` Y
- "interface" without `this font` means a collection of methods and contracts for their behaviour (aka API); **not necessarily a Java `interface`**
- "class" means non-abstract class unless otherwise specified

please remember to apply these definitions, they are important

### ok really what's LODIS

- Liskov Substitution Principle: if I'm dealing in Ys, then you should be able to give me an instance of any subtype of Y, and I shouldn't notice
- Open/Closed Principle: logic should be put into neat little easily swappable components
- Dependency Inversion Principle: components should specify and depend on a well-designed interface
- Interface Segregation Principle: sufficiently unrelated tasks should be in separate interfaces
- Single Responsibility Principle: classes should implement a maximum of one interface

### some notes

the Substitution Principle should never be broken, lest the program semantics come crashing down and burn in a relentless fire of confusion. it's bad

honestly, sometimes it's hard to tell the difference between the latter four, because violating one seems to almost necessitate violating at least one of the others.

as a sixth principle, I propose the Make a Reasonable Design Choice Principle: only apply the latter four principles if doing so actually improves your design.

## examples

(these examples are inspired by common Objective-C patterns.)

we want to display an unscrollable list of people's names.

### an initial (motivating) design

```java
class PeoplesNamesListView extends View {
    
    @Override
    public void draw() {
        String[] names = Database.database().query("select name from users;");
        var ctx = GraphicsContext.current();
        for (var name : names) {
            ctx.translate(0, -20);
            ctx.drawText(name);
        }
    }
    
    @Override
    public void scroll(double pixels) {
        throw new RuntimeException("no u scroll");
    }
    
}
```

it'll crash if the user tries to scroll. why? because the user of a `View` expects to be able to tell it to `scroll`, and we violated that contract.

let's apply the Substitution Principle:

```java
class PeoplesNamesListView extends View {
    
    @Override
    public void draw() {
        String[] names = Database.database().query("select name from users;");
        var ctx = GraphicsContext.current();
        for (var name : names) {
            ctx.translate(0, -20);
            ctx.drawText(name);
        }
    }
    
    @Override
    public void scroll(double amount) {
        GraphicsContext.current().flashScrollBar();
    }
    
}
```

we are now in the realm of sanity.

oops, the product owner wants the text to have a funky purple background. ok then

```java
class PeoplesNamesListView extends View {
    
  @Override
    public void draw() {
        String[] names = Database.database().query("select name from users;");
        var ctx = GraphicsContext.current();
        ctx.setTextBackground(new ScreenColor("#ff00ff"));
        for (var name : names) {
            ctx.translate(0, -20);
            ctx.drawText(name);
        }
    }
    
    @Override
    public void scroll(double amount) {
        GraphicsContext.current().flashScrollBar();
    }
    
}
```

oops, now the product owner wants the background to only be purple on the signup page, to entice new users. "screw the paying subscribers."

looks like we'll have to parameterize the color, i.e., apply the Open/Closed Principle.

```java
class PeoplesNamesListView extends View {
    
    ScreenColor textBackground;
    
    @Override
    public void draw() {
        String[] names = Database.database().query("select name from users;");
        var ctx = GraphicsContext.current();
        ctx.setTextBackground(textBackground);
        for (var name : names) {
            ctx.translate(0, -20);
            ctx.drawText(name);
        }
    }
    
    @Override
    public void scroll(double amount) {
        GraphicsContext.current().flashScrollBar();
    }
    
}
```

oops, now the product owner wants the list of people shown to vary based on some fancy new algorithm. looks like we'll have to write that in too.

```java
class PeoplesNamesListView extends View {
    
    ScreenColor textBackground;
    boolean useML;
    
    @Override
    public void draw() {
        String[] names;
        if (useML) {
            names = MLModel.model().suggestFromDatabase(Database.database());
        } else {
            names = Database.database().query("select name from users;");
        }
        var ctx = GraphicsContext.current();
        ctx.setTextBackground(textBackground);
        for (var name : names) {
            ctx.translate(0, -20);
            ctx.drawText(name);
        }
    }
    
    @Override
    public void scroll(double amount) {
        GraphicsContext.current().flashScrollBar();
    }
    
}
```

basically, this class is convoluted. it wants to choose the data to display, control how it's displayed, and handle user interaction like scrolling. reusing this class elsewhere would require parameterizing tons of things and adding conditional statements. we should find where to draw the line between reasonably configurable behaviour and totally unrelated behaviour, and separate those concerns into different components.

### a b07-enlightened design

overview of what we're about to do:

1. we just applied the Open/Closed Principle to parameterize the text background color. we'll apply it again shortly to instead parameterize behaviour at a broader level.
2. then we'll apply the Dependency Inversion Principle to allow us to achieve polymorphic (varying) behaviour, and reduce conditional logic in the component we just added.
3. then we'll apply the Interface Segregation Principle to allow us to combine the behaviour of different classes, instead of having to write a new class every time to do so. (this avoids a so-called "class explosion" of combinatorial proportion :)
4. then we'll apply the Single Responsibility Principle to reduce the complexity of all of our components.

#### step 1 (Open/Closed Principle)

our goal here is to turn `PeoplesNamesListView` into a general `ListView` class that can coordinate display of a list view, while leaving the drawing, fetching model objects, etc. to another class.

(I'll use the term "strategy" here. In Objective-C, this is called the "delegate" pattern; a class can delegate responsibilities to its delegate.)

```java
class ListView extends View {
    
    ListViewStrategy strategy;
    
    @Override
    public void draw() {
        var ctx = GraphicsContext.current();
        for (var item : strategy.getListItems()) {
            ctx.translate(0, -strategy.getHeightOfListItem(item));
            strategy.drawListItem(item, ctx);
        }
        strategy.draw(strategy.getListItems());
    }
    
    @Override
    public void scroll(double amount) {
      strategy.preventScroll();
    }
    
}

class ListViewStrategy {
    
    ScreenColor textBackground;
    boolean useML;
    
    public String[] getListItems() {
        if (useML) {
            return MLModel.model().suggestFromDatabase(Database.database());
        } else {
            return Database.database().query("select name from users;");
        }
    }
    
    public double getHeightOfListItem(String item) {
        return 20;
    }
    
    public void drawListItem(String item, GraphicsContext ctx) {
        ctx.setTextBackground(textBackground);
        ctx.drawText(string);
    }
    
    public void preventScroll() {
        GraphicsContext.current().flashScrollBar();
    }
    
}
```

#### step 2 (Dependency Inversion Principle)

our ListViewStrategy is still quite rigid. it's parameterized, but not very much; and it still uses conditional logic to determine how to fetch the data.

we should be able to pass different `ListViewStrategy`s to get list views that look different, and source data differently, but still all act like list views.

```java
class ListView<ListItem> extends View {
    
    ListViewStrategy<ListItem> strategy;
    
    @Override
    public void draw() {
        var ctx = GraphicsContext.current();
        for (var item : strategy.getListItems()) {
            ctx.translate(0, -strategy.getHeightOfListItem(item));
            strategy.drawListItem(item, ctx);
        }
    }
    
    @Override
    public void scroll(double amount) {
        strategy.preventScroll();
    }
    
}

interface ListViewStrategy<ListItem> {
    
    ListItem[] getListItems();
    
    double getHeightOfListItem(ListItem item);
    void drawListItem(ListItem item, GraphicsContext ctx);
    
    void preventScroll();
    
}

class RegularPeoplesNamesListViewStrategy implements ListViewStrategy<String> {
    
    // Using "Color" instead of "ScreenColor" is another example of applying DIP.
    Color textBackground;
    
    public String[] getListItems() {
        return Database.database().query("select name from users;");
    }
    
    public double getHeightOfListItem(String item) {
        return 20;
    }
    
    public void drawListItem(String item, GraphicsContext ctx) {
        ctx.setTextBackground(textBackground);
        ctx.drawText(string);
    }
    
    public void preventScroll() {
        GraphicsContext.current().flashScrollBar();
    }
    
}

class SignupPagePeoplesNamesListViewStrategy implements ListViewStrategy<String> {
    
    public String[] getListItems() {
        return MLModel.model().suggestFromDatabase(Database.database());
    }
    
    public double getHeightOfListItem(String item) {
        return 20;
    }
    
    public void drawListItem(String item, GraphicsContext ctx) {
        ctx.setTextBackground(new ScreenColor("#ff00ff"));
        ctx.drawText(string);
    }
    
    public void preventScroll() {
        GraphicsContext.current().flashScrollBar();
    }
    
}
```

#### step 3 (Interface Segregation Principle)

our `ListViewStrategy` interface is fantastic at allowing us to customize list views, but it requires we write a new class every time, even if part of our behaviour is already implemented. 

if we can instead compose a list view from small, fairly independent components, we can customize its behaviour more easily, and reuse more code.

```java
class ListView<ListItem> extends View {
    
    ListDataSource<ListItem> dataSource;
    ListItemDrawer<ListItem> itemDrawer;
    ScrollPreventer scrollPreventer;
    
    @Override
    public void draw() {
        var ctx = GraphicsContext.current();
        for (var item : dataSource.getListItems()) {
            ctx.translate(0, -itemDrawer.getHeightOfListItem(item));
            itemDrawer.drawListItem(item, ctx);
        }
    }
    
    @Override
    public void scroll(double amount) {
        scrollPreventer.preventScroll();
    }
    
}

interface ListDataSource<ListItem> {
    
    ListItem[] getListItems();
    
}

interface ListItemDrawer<ListItem> {
    
    double getHeightOfListItem(ListItem item);
    void drawListItem(ListItem item, GraphicsContext ctx);
    
}

interface ScrollPreventer {
    
    void preventScroll();
    
}

class RegularPeoplesNamesListViewStrategy implements ListDataSource<String>, ListItemDrawer<String>, ScrollPreventer {
    
    // Using "Color" instead of "ScreenColor" is another example of applying DIP.
    Color textBackground;
    
    public String[] getListItems() {
        return Database.database().query("select name from users;");
    }
    
    public double getHeightOfListItem(String item) {
        return 20;
    }
    
    public void drawListItem(String item, GraphicsContext ctx) {
        ctx.setTextBackground(textBackground);
        ctx.drawText(string);
    }
    
    public void preventScroll() {
        GraphicsContext.current().flashScrollBar();
    }
    
}

class SignupPagePeoplesNamesListViewStrategy implements ListDataSource<String>, ListItemDrawer<String>, ScrollPreventer {
    
    public String[] getListItems() {
        return MLModel.model().suggestFromDatabase(Database.database());
    }
    
    public double getHeightOfListItem(String item) {
        return 20;
    }
    
    public void drawListItem(String item, GraphicsContext ctx) {
        ctx.setTextBackground(new ScreenColor("#ff00ff"));
        ctx.drawText(string);
    }
    
    public void preventScroll() {
        GraphicsContext.current().flashScrollBar();
    }
    
}
```

note that this design (similar to one shown in lectures) effectively defines `ListViewStrategy<ListItem> extends ListDataSource<ListItem>, ListItemDrawer<ListItem>, ScrollPreventer` and then parameterizes the list view on that. it does solve a problem: it allows you to implement `ListDataSource`s and use them without having to care about the full `ListViewStrategy` interface. however, it does not allow you to easily compose existing implementations of the interfaces—e.g., you couldn't combine existing an `ListViewDataSource` and `ListItemDrawer` together—since Java classes can only inherit from a single concrete class. you could accomplish it by keeping an instance of each concrete class as a field and forwarding each method to the appropriate object, but that's an issue with the original design, IMO.

we'll fix the problems I just outlined in this next step.

#### step 4 (Single Responsibility Principle)

```java
class ListView<ListItem> extends View {
    
    ListDataSource<ListItem> dataSource;
    ListItemDrawer<ListItem> itemDrawer;
    ScrollPreventer scrollPreventer;
    
    @Override
    public void draw() {
        var ctx = GraphicsContext.current();
        for (var item : dataSource.getListItems()) {
            ctx.translate(0, -itemDrawer.getHeightOfListItem(item));
            itemDrawer.drawListItem(item, ctx);
        }
    }
    
    @Override
    public void scroll(double amount) {
        scrollPreventer.preventScroll();
    }
    
}

interface ListDataSource<ListItem> {
    
    ListItem[] getListItems();
    
}

interface ListItemDrawer<ListItem> {
    
    double getHeightOfListItem(ListItem item);
    void drawListItem(ListItem item, GraphicsContext ctx);
    
}

interface ScrollPreventer {
    
    void preventScroll();
    
}


class PeoplesNamesDBFetch implements ListDataSource<String> {
    
    public String[] getListItems() {
        return Database.database().query("select name from users;");
    }
    
}

class PeoplesNamesMLSuggest implements ListDataSource<String> {
    
    public String[] getListItems() {
        return MLModel.model().suggestFromDatabase(Database.database());
    }
    
}

class StringDrawer implements ListItemDrawer<String> {
    
    Color textBackground;
    
    public double getHeightOfListItem(String item) {
        // Could parameterize this, too.
        return 20;
    }
    
    public void drawListItem(String item, GraphicsContext ctx) {
        ctx.setTextBackground(textBackground);
        ctx.drawText(string);
    }
    
}

class FlashScrollPreventer implements ScrollPreventer {
    
    public void preventScroll() {
        GraphicsContext.current().flashScrollBar();
    }
    
}
```

you might remark that this all just looks like a bunch of functions and function signatures with extra long and important-sounding names. I agree with you, but note that the real-world version of this code would involve many more methods in each interface. by using Java `interface`s to define the API, we gain the ability to bundle together very closely related functions. (and, well, Java forces you to wrap all functions in classes anyway.)

### conclusion

we've just taken a very rigid (but simple) class that displays people's names in a list view, and refactored it into many modular, reusable components for building list views, out of any kind of data, and with highly flexible display parameters. I hope this clarified more than it confused.

it may not come across well, though I hope it does, but this kind of design is absolutely viable in the real world. the eventual design was inspired by Apple's AppKit Objective-C framework, as I'm quite familiar with it. a design very similar to this (though not quite as modular) appears across much of AppKit.
