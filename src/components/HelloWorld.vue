<template>
  <div>
    <el-input
      type="textarea"
      :rows="2"
      placeholder="请输入内容"
      @change="sqlchange"
      :autosize="{ minRows: 8, maxRows: 16 }"
      v-model="sqlinput"
    >
    </el-input>
    <div style="margin: 20px 0"></div>
    <vue-json-editor
      v-model="schema"
      :showBtns="true"
      :mode="'text'"
      lang="zh"
      @json-change="onJsonChange"
      @json-save="onJsonSave"
      @has-error="onError"
    />
    <br />
    <div style="margin: 20px 0"></div>
    <el-row>
      <el-col :span="24">
        <s-json-schema-editor
          :key="schemaKey"
          :schema.sync="schema"
          :show-default-value="true"
          :is-mock="true"
          @schema-change="onSchemaChange"
        >
        </s-json-schema-editor>
      </el-col>
    </el-row>
    <div style="margin: 20px 0"></div>
    <el-row>
      <el-input
        type="textarea"
        :rows="16"
        placeholder="请输入内容"
        @change="sqlchange"
        :autosize="{ minRows: 8, maxRows: 16 }"
        v-model="output"
      >
      </el-input>
    </el-row>
  </div>
</template>

<script>
import vueJsonEditor from "vue-json-editor";
import { Parser } from "sql-ddl-to-json-schema";
export default {
  name: "HelloWorld",
  components: { vueJsonEditor },
  data() {
    return {
      schemaKey: "19878878",
      schema: {
        type: "object",
        title: "title",
        properties: {
          field_1: {
            type: "string",
          },
        },
      },
      jsonformat: {},
      sqlinput: `CREATE TABLE \`gb_goods\` (
          \`goods_id\` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '商品id',
          PRIMARY KEY (\`goods_id\`) USING BTREE
          ) ENGINE = InnoDB AUTO_INCREMENT = 1 CHARACTER SET = utf8mb4 COMMENT = '商品表' ROW_FORMAT = Dynamic;`,
      output: "",
    };
  },
  created() {},
  mounted() {
    this.sqlchange(this.sqlinput);
    this.schemaKey = Date.now();
  },
  methods: {
    onJsonChange(value) {
      this.onJsonSave(value);
    },
    onJsonSave(value) {
      this.schemaKey = Date.now();
      this.jsonformat = value;
      this.schema = Object.assign({}, this.jsonformat);
    },
    sqlchange(v) {
      const parser = new Parser("mysql");
      const options = { useRef: false };
      parser.feed(v);
      const doc = parser.toJsonSchemaArray(options);
      const ob = JSON.parse(JSON.stringify(doc[0]));
      this.schema = Object.assign({}, ob);
      this.schemaKey = Date.now();
    },
    onError(value) {
      console.log("json错误了value:", value);
    },
    checkJson() {
      if (this.hasJsonFlag == false) {
        alert("json验证失败");
        return false;
      } else {
        alert("json验证成功");
        return true;
      }
    },
    onSchemaChange(v) {
      this.schema = JSON.stringify(v, null, 2);
      //
      this.handleObjectOutput(v);
    },
    handleObjectOutput(v) {
      function toCamelCase(str) {
        var regExp = /[-_]\w/gi;
        return titleCase(
          str.replace(regExp, function (match) {
            return match.charAt(1).toUpperCase();
          })
        );
      }

      function titleCase(str) {
        const newStr = str.slice(0, 1).toUpperCase() + str.slice(1);
        return newStr;
      }

      function lowerCase(str) {
        const newStr = str.slice(0, 1).toLowerCase() + str.slice(1);
        return newStr;
      }

      function typeMap(str) {
        const kv = {
          integer: "int64",
          string: "string",
          number: "float64",
        };
        return kv[str];
      }

      const requires = v.required;
      const properties = v.properties;
      const tableName = toCamelCase(v.title);
      const tableNameLower = lowerCase(tableName);
      var enumUpdate = ``;
      var enumdefine = ``;
      var paramsheader = `
    type ${tableNameLower}Q struct {
      Mgr  *${tableName}Mgr
      opts []GormOptionFunc
    }

    func (obj *${tableName}Mgr) Q() *${tableNameLower}Q {
      return &${tableNameLower}Q{
        Mgr: obj,
      }
    }

    // QueryDefault 查询列表
    func (obj *${tableNameLower}Q) List(ctx context.Context, value interface{}) (int64, error) {
      var cnt int64
      obj.Query(ctx).Offset(-1).Find(value).Count(&cnt)
      err := obj.Query(ctx).Order("update_time desc").Find(value).Error
      return cnt, err
    }

    //QueryDefault 查询单个
    func (obj *${tableNameLower}Q) One(ctx context.Context, value interface{}) error {
      Q := obj.Query(ctx)
      cache_key := ""
      // 缓存只适用于单行全列的情况
      if k, _ := Q.InstanceGet("cache_key"); len(obj.opts) == 1 && k != nil {
        cache_key = utils.AsString(k)
        Q = Q.Select("*")
      }
      return obj.Mgr.Cache.Query(ctx, cache_key, value, func(ctx context.Context) error {
        err := Q.First(value).Error
        if errors.Is(err, gorm.ErrRecordNotFound) {
          return errors.ErrIdCanNotFound
        }
        return err
      })
    }

    func (obj *${tableNameLower}Q) Query(ctx context.Context) *gorm.DB {
      db := obj.Mgr.DB.WithContext(ctx).Model(&${tableName}{})
      for _, f := range obj.opts {
        db = f(db)
      }
      return db
    }

    func (obj *${tableNameLower}Q) Select(strings ...string) *${tableNameLower}Q {
      fn := func(db *gorm.DB) *gorm.DB {
        if len(strings) > 0 {
          var ss []string
          for _, s := range strings {
            ss = append(ss, obj.Mgr.PreTableName(s))
          }
          db = db.Select(ss)
        }
        return db
      }
      obj.opts = append(obj.opts, fn)
      return obj
    }

      type ${tableName}ReqParams struct {
        Query    *${tableName}Params \`json:"query,omitempty"\`
        Export   bool           \`json:"export,omitempty"\`
        Fields   []string       \`json:"fields,omitempty"\`
        PageNum  int            \`json:"page_num,omitempty"\`
        PageSize int            \`json:"page_size,omitempty"\`
      }
      type ${tableName}Params struct {\n`;
      var center = ``;
      var paramstail = `}`;
      var optCommon = ``;

      var filterHeader = `
      func (opt *${tableNameLower}Q) Filter(para *${tableName}ReqParams) *${tableNameLower}Q {
        	if para != nil {
		        opt.Select(para.Fields...)
		        opt.Pagination(para)
		        if para.Query != nil {
      `;
      var filtercenter = ``;
      var filtertail = `}}
      return opt}`;

      var primary = ``;
      Object.keys(properties).forEach(function (key) {
        const o = properties[key];
        const skey = toCamelCase(key);
        if (Object.prototype.hasOwnProperty.call(o, "$comment")) {
          primary = skey;
        }
      });

      Object.keys(properties).forEach(function (key) {
        const o = properties[key];
        const skey = toCamelCase(key);
        const type = typeMap(o.type);
        if (
          Object.prototype.hasOwnProperty.call(o, "enum") &&
          o.enum.length > 0
        ) {
          const enumlist = o.enum;
          const enumdesc = o.enumDesc;
          var enumbegin = `
          type ${skey} ${type} 
            const (
          `;
          var enumcenter = ``;
          var enumend = `)`;
          enumdesc.split("\n").forEach(function (value, index) {
            const v = enumlist[index];
            var s = `
              ${skey}${value} ${skey} = ${v} \n
            `;
            var f = `
              func (g ${skey}) ${value}() bool {
                	return g == ${skey}${value}
              } \n
              func (obj *${tableName}Mgr) ${value}(ctx context.Context, id int64) error {
              	return obj.Updates(ctx, &${tableName}{${skey}: ${skey}${value}}, obj.Q().${primary}(id))
              } \n
            `;
            console.log(value);
            enumcenter += s;
            enumUpdate += f;
          });
          enumdefine += enumbegin + enumcenter + enumend;
        }

        if (key.indexOf("_time") > -1) {
          center += `${skey}Interval []interface{} \`json:"${key}|interval,omitempty"\`\n`;
          filtercenter += `	
          if len(para.Query.${skey}Interval) > 0 {
				    opt.${skey}Interval(para.Query.${skey}Interval)
			    }
          `;
          optCommon += `
            func (obj *${tableNameLower}Q) ${skey}Interval(interval []interface{}) *${tableNameLower}Q {
              fn := func(db *gorm.DB) *gorm.DB {
                	db = db.Clauses(
                      TimeStampDate{
                        Column: "create_time",
                        Values: interval,
                      })
		            return db
	            }
              obj.opts = append(obj.opts, fn)
              return obj
            }
            \n
          `;
        }

        if (key.indexOf("_id") > -1 || key == "id") {
          center += `${skey}In []${type} \`json:"${key}|in,omitempty"\`\n`;
          filtercenter += `	
          if len(para.Query.${skey}In) > 0 {
				    opt.${skey}In(para.Query.${skey}In...)
			    }
          `;
          optCommon += `
            func (obj *${tableNameLower}Q) ${skey}In(${skey}s ...${type}) *${tableNameLower}Q {
              	fn := func(db *gorm.DB) *gorm.DB {
		            db = db.Where(obj.Mgr.PreTableName("${key} in (?)"), ${skey}s)
		            return db
	             }
              obj.opts = append(obj.opts, fn)
              return obj
            }
            \n
          `;
        }

        if (requires.indexOf(key) > -1) {
          center += `${skey} ${type} \`json:"${key},omitempty"\`\n`;
          filtercenter += `	
          if para.Query.${skey} != "" {
				    opt.${skey}(para.Query.${skey})
			    }
          `;
          optCommon += `
            func (obj *${tableNameLower}Q) ${skey}(${skey} ${type}) *${tableNameLower}Q {
              fn := func(db *gorm.DB) *gorm.DB {
                db = db.Where(obj.Mgr.PreTableName("${key} = ?"), ${skey})
                return db
              }
              obj.opts = append(obj.opts, fn)
              return obj
            }
            \n
          `;
          if (type == "string") {
            center += `${skey}Like ${type} \`json:"${key}|like,omitempty"\`\n`;
            filtercenter += `	
            if para.Query.${skey}Like != "" {
              opt.${skey}Like(para.Query.${skey}Like)
            }
            `;
            optCommon += `
            func (obj *${tableNameLower}Q) ${skey}Like(${skey} ${type}) *${tableNameLower}Q {
              fn := func(db *gorm.DB) *gorm.DB {
                db = db.Where(obj.Mgr.PreTableName("${key} like ?"), "%"+${skey}+"%")
                return db
              }
              obj.opts = append(obj.opts, fn)
              return obj
            }
            \n
          `;
          }
        }
      });
      this.output =
        enumdefine +
        enumUpdate +
        paramsheader +
        center +
        paramstail +
        "\n" +
        optCommon +
        filterHeader +
        filtercenter +
        filtertail;
    },
  },
};
</script>

<style>
</style>
