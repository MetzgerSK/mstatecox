This repository hosts the development version of `mstatecox`, a Stata package written by Shawna K. Metzger and Benjamin T. Jones to simulate transition probabilities out of semi-parametric multistate duration models.

Any files committed to `master` _should_ (operative word) be fairly stable.  We'll keep tests of new features to separate branches before merging them back in.

## To Install
### Development
Technically, you can manually install using `net install...`, with the URL being the repo's address.

However, if you'd like a bit more fine-grained control over what you install and keeping your files up to date, you can install E.F. Haghish's `github` command:
```{stata}
net install github, from("https://haghish.github.io/github/")
```

Once `github`'s installed, getting `mstatecox`'s most recent dev version (branch: `master`) is as easy as:

```{stata}
github install MetzgerSK/mstatecox
```

You can also install specific versions of `mstatecox` using `github`'s `version()` option.

### Official
We consider official `mstatecox` releases to be those disseminated via _Stata Journal_.  The most recent official release was in spring 2019.  To install it:

```{stata}
net sj 19-3 st0534_1
```
The commits corresponding to the official releases are also tagged appropriately using GitHub's release log functionality.

## Official Citation of Record
Metzger, Shawna K., and Benjamin T. Jones.  2018.  “`mstatecox`: A Package for Simulating Transition Probabilities from Semiparametric Multistate Survival Models.”  _Stata Journal_ 18 (3): 533–63.
