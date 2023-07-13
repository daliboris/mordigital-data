# MORDigital Data

Data repository for MORDigital TEI Publisher application

If you want change the name of this eXist-db module do it in this places:

- `repo.xml`
  - `<description>`
  - `<website>`
  - `<target>`
  - `<permissions>`
  - `<changelog>`
- `expath-pkg.xml`
  - `<package>`
    - @abbrev 
    - @name
    - @version
  - `<title>`
  - `<home>`

## Useful scripts

The following scripts use the `xst` command line tool (<https://github.com/eXist-db/xst>) to manipulate your code, data and eXist-db modules.

To install `xst`, follow the [instructions](https://github.com/eXist-db/xst) on the GitHub project repository.

If the script has two versions, the first one - with the variable (`SET project=`) - can be used from the command line on Windows. The second one - with the full path instead of the parameter - can be used either from PowerShell or from the command line on Windows.

**If you want change the name of this eXist-db module** in the first version of the script set parameter value to the new name (without `-data` suffix), in the second version change the full name.

### Installing data module

#### Install

```script
SET project=mordigital
xst package install --config admin.xstrc ./build/%project%-data.xar
```

```script
xst package install --config admin.xstrc ./build/mordigital-data.xar
```

#### Uninstall

```script
SET project=mordigital
xst package uninstall --config admin.xstrc %project%-data
```

```script
xst package uninstall --config admin.xstrc mordigital-data
```

### Data

#### Uploading dictionary data

```script
SET project=mordigital
xst upload -i "*.xml" -v ../local/data/ /db/apps/%project%-data/data/dictionaries --config %project%.xstrc
xst upload -i "*.xml" -v ../local/data/latest/ /db/apps/%project%-data/data/dictionaries --config %project%.xstrc
```

```script
xst upload -i "*.xml" -v ../local/data/latest/ /db/apps/mordigital-data/data/dictionaries --config mordigital.xstrc
```

#### Deleting

```script
SET project=mordigital
xst remove /db/apps/%project%-data/data/dictionaries/*.xml --config %project%.xstrc
```

#### Uploading xconf data

```script
SET project=mordigital
xst upload --include "*.xconf" --verbose --apply-xconf ./data/dictionaries/ /db/apps/%project%-data/data/dictionaries --config admin.xstrc
```

```script
xst upload --include "*.xconf" --verbose --apply-xconf ./data/dictionaries/ /db/apps/mordigital-data/data/dictionaries --config admin.xstrc
```

#### Uploading index module

```script
SET project=mordigital
xst upload --include "index.xql" --verbose ./ /db/apps/%project%-data --config admin.xstrc
```

```script
xst upload --include "index.xql" --verbose ./ /db/apps/mordigital-data --config admin.xstrc
```

#### Reindex content

```script
SET project=mordigital
xst execute "xmldb:reindex('/db/apps/%project%-data/data/dictionaries')" --config admin.xstrc
```

```script
xst execute "xmldb:reindex('/db/apps/mordigital-data/data/dictionaries')" --config admin.xstrc
```
