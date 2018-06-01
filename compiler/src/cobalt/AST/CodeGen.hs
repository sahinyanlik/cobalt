{-# LANGUAGE FlexibleContexts #-}

module AST.CodeGen where

import Data.Scientific
import Data.Char
import GHC.Float
import Data.List
import Data.Maybe
import Text.Format
import Control.Monad
import Control.Monad.Exception
import qualified Data.ByteString.Lazy as B
import Data.ByteString.Lazy.Char8 (pack)
import Data.Traversable

import qualified AST.IR as IR
import JVM.ClassFile
import JVM.Converter
import JVM.Assembler
import JVM.Builder
import JVM.Exceptions
import qualified Java.Lang
import qualified Java.IO
import SymbolTable.SymbolTable
import Util.GeneralUtil

class CodeGen a where
    genCode :: Throws UnexpectedEndMethod e => a -> Generate e ()

instance CodeGen IR.ModuleIR where
    genCode (IR.ModuleIR header modules) = forM_ modules genCode

instance CodeGen IR.ModelIR where
    genCode (IR.ModelIR modelName modelType modelModifiers modelFields modelParent modelParentArguments modelInterfaces modelBody) = do
        newMethod [ACC_PUBLIC] (pack "<init>") [] ReturnsVoid $ do
            setStackSize 1
            aload_ I0
            invokeSpecial Java.Lang.object Java.Lang.objectInit
            i0 RETURN
        genCode modelBody

instance CodeGen IR.MethodIR where
    genCode (IR.MethodIR methodName methodAnns methodParams methodModifiers methodReturnType methodBody) = do

        -- Temporary. Allows us to write tests with a main method to execute by just naming the method main.
        let name = extractName methodName
        if name == "main"
        then do
            newMethod [ACC_PUBLIC, ACC_STATIC] (pack "main") [arrayOf Java.Lang.stringClass] ReturnsVoid (genCode methodBody >> i0 RETURN)
        else do
            let convertModifier m = case m of
                                            IR.PublicIR        -> ACC_PUBLIC
                                            IR.ProtectedIR     -> ACC_PROTECTED
                                            IR.AbstractIR      -> ACC_ABSTRACT
                                            IR.FinalIR         -> ACC_FINAL
                                            (_)               -> ACC_PRIVATE

            let modifiers = map convertModifier methodModifiers

            newMethod modifiers (pack $ extractName methodName) [] ReturnsVoid (genCode methodBody >> i0 RETURN)
        return ()

instance CodeGen IR.BlockIR where
    genCode (IR.InlineIR expression) = genCode expression
    genCode (IR.DoBlockIR statement) = genCode statement

instance CodeGen IR.ExprIR where
    genCode (IR.BlockExprIR expressions) = forM_ expressions genCode
    genCode (IR.IntConstIR value) = genIntConst value
    genCode (IR.FloatConstIR value)
        | value == 0 = fconst_0
        | value == 1 = fconst_1
        | value == 2 = fconst_2
        | value >= -32768 && value <= 32767 = i8 LDC1 (CFloat $ double2Float value)
        | otherwise = error $ show otherwise
    genCode (IR.BoolConstIR value) = if value then iconst_1 else iconst_0
    genCode (IR.StringLiteralIR value) = loadString value
    genCode (IR.ABinaryIR op expr1 expr2) = do
        genCode expr1
        genCode expr2
        genCode op
    genCode (a) = error $ show a

instance CodeGen IR.StmtIR where
    genCode (IR.AssignIR name valType immutable assignment) = do
        genCode assignment
        istore_ (fromIntegral (ord '\n'))
    genCode (IR.BlockStmtIR statements) = forM_ statements genCode
    genCode (IR.MethodDefIR method) = genCode method
    genCode (IR.ModelDefIR modelDef) = genCode modelDef
    genCode (IR.ExprAsStmtIR expression) = genCode expression
    genCode (IR.IfIR condition ifStmt elseStmt) = do
        genCode condition
        genCode ifStmt
        case elseStmt of
            Just s -> genCode s
            Nothing -> return ()
    genCode (IR.PrintIR expression expressionType) = do
        getStaticField Java.Lang.system Java.IO.out
        genCode expression
        invokeVirtual Java.IO.printStream (Java.IO.print $ MethodSignature [expressionType] ReturnsVoid)
        return ()
    genCode (IR.PrintlnIR expression expressionType) = do
        getStaticField Java.Lang.system Java.IO.out
        genCode expression
        invokeVirtual Java.IO.printStream (Java.IO.println $ MethodSignature [expressionType] ReturnsVoid)
        return ()
    genCode (a) = error $ show a

extractName (IR.NameIR value) = value

genIntConst value
    | value == 0 = iconst_0
    | value == 1 = iconst_1
    | value == 2 = iconst_2
    | value == 3 = iconst_3
    | value == 4 = iconst_4
    | value == 5 = iconst_5
    | value >= -128 && value <= 127 = bipush $ fromIntegral value
    | value >= -32768 && value <= 32767 = sipush $ fromIntegral value
    | otherwise = error $ show otherwise

instance CodeGen IR.ABinOpIR where
    genCode (IR.AddIR expressionType)       = case expressionType of
                                                  JVM.ClassFile.IntType    -> iadd
                                                  JVM.ClassFile.LongInt    -> ladd
                                                  JVM.ClassFile.FloatType  -> dadd
                                                  JVM.ClassFile.DoubleType -> fadd
    genCode (IR.SubtractIR expressionType)  = case expressionType of
                                                  JVM.ClassFile.IntType    -> isub
                                                  JVM.ClassFile.LongInt    -> lsub
                                                  JVM.ClassFile.FloatType  -> dsub
                                                  JVM.ClassFile.DoubleType -> fsub
    genCode (IR.MultiplyIR expressionType)  = case expressionType of
                                                  JVM.ClassFile.IntType    -> imul
                                                  JVM.ClassFile.LongInt    -> lmul
                                                  JVM.ClassFile.FloatType  -> dmul
                                                  JVM.ClassFile.DoubleType -> fmul
    genCode (IR.DivideIR expressionType)    = case expressionType of
                                                  JVM.ClassFile.IntType    -> idiv
                                                  JVM.ClassFile.LongInt    -> ldiv
                                                  JVM.ClassFile.FloatType  -> ddiv
                                                  JVM.ClassFile.DoubleType -> fdiv
